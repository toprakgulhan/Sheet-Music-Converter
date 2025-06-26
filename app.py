from flask import Flask, request, jsonify, abort, Response
from flask_sqlalchemy import SQLAlchemy
import tempfile, os, subprocess, traceback, re, base64

from basic_pitch.inference import predict
from music21 import converter, stream

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI']        = 'postgresql://postgres:123456789@localhost:5432/SheetMusic'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['MAX_CONTENT_LENGTH']             = 100 * 1024 * 1024  # 100 MB

db = SQLAlchemy(app)

class Transcription(db.Model):
    __tablename__  = 'transcriptions'
    id             = db.Column(db.Integer, primary_key=True)
    filename       = db.Column(db.Text)
    mimetype       = db.Column(db.Text)
    pages          = db.Column(db.JSON)       # stored as base64 strings
    created_at     = db.Column(db.DateTime, server_default=db.func.now())

def transcribe_audio(path):
    print("[transcribe_audio] loading", path, flush=True)
    if not os.path.exists(path) or os.path.getsize(path) == 0:
        raise ValueError("No file or empty")
    _, midi_data, _ = predict(path)
    print("[transcribe_audio] done", flush=True)
    return midi_data

def normalize_score(score):
    # your duration‐rounding or cleanup logic could go here
    return score

def convert_to_score(midi):
    print("[convert_to_score] writing MIDI → temp file", flush=True)
    with tempfile.NamedTemporaryFile(suffix=".mid", delete=False) as tmp:
        midi.write(tmp.name)
        mid_path = tmp.name

    print("[convert_to_score] parsing MIDI", flush=True)
    score = converter.parse(mid_path)
    os.remove(mid_path)

    score = normalize_score(score)

    print("[convert_to_score] splitting at durations", flush=True)
    split_r = score.splitAtDurations()
    if isinstance(split_r, tuple):
        s2 = stream.Score()
        for part in split_r:
            s2.append(part)
        score = s2

    print("[convert_to_score] done", flush=True)
    return score

def generate_png_pages(score):
    print("[generate_png_pages] writing MusicXML → temp file", flush=True)
    xmlf = tempfile.NamedTemporaryFile(suffix=".musicxml", delete=False, mode="w", encoding="utf-8")
    score.write("musicxml", fp=xmlf.name)
    xmlf.close()

    # strip out any <time-modification> tags
    xml = open(xmlf.name, encoding="utf-8").read()
    clean = re.sub(r"<time-modification>.*?</time-modification>", "", xml, flags=re.DOTALL)
    open(xmlf.name, "w", encoding="utf-8").write(clean)

    # call MuseScore CLI in that temp dir
    ms_exe = os.getenv("MUSESCORE_PATH", r"C:\Program Files\MuseScore 3\bin\MuseScore3.exe")
    tmpdir   = os.path.dirname(xmlf.name)
    basename = os.path.splitext(os.path.basename(xmlf.name))[0]

    try:
        print(f"[generate_png_pages] running MuseScore → {basename}.png", flush=True)
        res = subprocess.run(
            [ms_exe, xmlf.name, "-o", f"{basename}.png"],
            cwd=tmpdir, capture_output=True, text=True, timeout=20
        )
        if res.returncode != 0:
            print("[generate_png_pages] MuseScore error:", res.stderr, flush=True)
            return []
    except Exception as e:
        print("[generate_png_pages] subprocess error:", e, flush=True)
        return []
    finally:
        os.remove(xmlf.name)

    pages = []
    idx = 1
    while True:
        fn = os.path.join(tmpdir, f"{basename}-{idx}.png")
        if not os.path.exists(fn):
            break
        print(f"[generate_png_pages] loading page #{idx}", flush=True)
        with open(fn, "rb") as fobj:
            pages.append(fobj.read())
        os.remove(fn)
        idx += 1

    # fallback single‐page if no numbered pages found
    single = os.path.join(tmpdir, f"{basename}.png")
    if not pages and os.path.exists(single):
        print("[generate_png_pages] loading single‐page", flush=True)
        with open(single, "rb") as fobj:
            pages.append(fobj.read())
        os.remove(single)

    print(f"[generate_png_pages] collected {len(pages)} page(s)", flush=True)
    return pages

@app.route("/transcribe", methods=["POST"])
def transcribe():
    print("[/transcribe] start", flush=True)
    if "file" not in request.files:
        abort(400, "No file part")
    f = request.files["file"]
    if not f.filename:
        abort(400, "Empty filename")

    suffix = os.path.splitext(f.filename)[1]
    upload_tmp = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    f.save(upload_tmp.name)
    upload_tmp.close()
    print(f"[/transcribe] saved upload → {upload_tmp.name}", flush=True)

    try:
        midi      = transcribe_audio(upload_tmp.name)
        score     = convert_to_score(midi)
        pages_bin = generate_png_pages(score)
    except Exception as e:
        traceback.print_exc()
        abort(500, str(e))
    finally:
        os.remove(upload_tmp.name)
        print(f"[/transcribe] cleaned up upload", flush=True)

    if not pages_bin:
        abort(500, "No pages generated")

    # store base64 in DB
    pages_b64 = [base64.b64encode(p).decode("ascii") for p in pages_bin]
    rec = Transcription(
        filename = f.filename,
        mimetype = "application/json",
        pages    = pages_b64
    )
    db.session.add(rec)
    db.session.commit()
    print(f"[/transcribe] saved record ID={rec.id}", flush=True)

    # only return id + page_count
    resp = jsonify({
        "id":         rec.id,
        "page_count": len(pages_b64)
    })
    print(f"[/transcribe] returning id & page_count", flush=True)
    return resp

@app.route("/sheets", methods=["GET"])
def list_sheets():
    print("[/sheets] list metadata", flush=True)
    recs = Transcription.query.order_by(Transcription.created_at.desc()).all()
    out = []
    for r in recs:
        count = len(r.pages) if isinstance(r.pages, list) else 0
        out.append({
            "id":         r.id,
            "filename":   r.filename,
            "created_at": r.created_at.isoformat(),
            "page_count": count
        })
    return jsonify(out)

@app.route("/sheets/<int:sheet_id>", methods=["GET"])
def get_sheet(sheet_id):
    print(f"[/sheets/{sheet_id}] metadata", flush=True)
    r = Transcription.query.get_or_404(sheet_id)
    return jsonify({
        "id":         r.id,
        "filename":   r.filename,
        "created_at": r.created_at.isoformat(),
        "page_count": len(r.pages)
    })

@app.route("/sheets/<int:sheet_id>/pages/<int:idx>", methods=["GET"])
def get_sheet_page(sheet_id, idx):
    print(f"[/sheets/{sheet_id}/pages/{idx}] serving PNG", flush=True)
    r = Transcription.query.get_or_404(sheet_id)
    if idx < 0 or idx >= len(r.pages):
        abort(404)
    png = base64.b64decode(r.pages[idx])
    return Response(png, mimetype="image/png")

@app.route("/sheets/<int:sheet_id>", methods=["DELETE"])
def delete_sheet(sheet_id):
    print(f"[/sheets/{sheet_id}] DELETE", flush=True)
    r = Transcription.query.get_or_404(sheet_id)
    db.session.delete(r)
    db.session.commit()
    return jsonify({"deleted": sheet_id})

@app.route("/", methods=["GET"])
def index():
    return """
    <html><body>
      <h2>Sheet Music Transcriber</h2>
      <form action="/transcribe" method="post" enctype="multipart/form-data">
        <input type="file" name="file" accept=".wav,.mp3,.mid,.midi" required>
        <input type="submit" value="Transcribe">
      </form>
    </body></html>
    """

if __name__ == "__main__":
    print("== Starting Flask server ==", flush=True)
    app.run(host="0.0.0.0", port=5000, debug=True)
