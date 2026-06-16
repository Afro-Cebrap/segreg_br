import os
import io
import datetime
import google.auth
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from google import genai
from google.cloud import storage
from pypdf import PdfReader

DRIVE_FOLDER_ID = "1OZTMSv-8Cq4mjMSQEp6b3zRdvL5NN1ES"
CACHE_PATH = "config/guidelines_cache.md"
LIBRARY_BLOB = "biblioteca_raw.md"

# --- Configuração do modelo (Vertex AI) ---
VERTEX_PROJECT  = os.environ.get("GOOGLE_CLOUD_PROJECT", "mapa-da-segregacao")
VERTEX_LOCATION = os.environ.get("GOOGLE_CLOUD_LOCATION", "global")
GEMINI_MODEL    = os.environ.get("GEMINI_MODEL", "gemini-3.1-pro-preview")

# Bucket privado para a biblioteca crua (texto integral de papers NÃO vai para o Git público).
KB_BUCKET = os.environ.get("KB_BUCKET", "")

# --- Curadoria: o que NÃO entra na base de conhecimento ---
EXCLUDE_FOLDERS = {"esbocos"}
EXCLUDE_NAME_MARKERS = ["cópia de", "[em construção]"]

# --- Fontes primárias / biblioteca ---
PRIMARY_FOLDER_MARKERS = ["biblioteca"]
PRIMARY_NAME_MARKERS = ["compendio_territorios_negros"]


def is_primary_source(name, current_path):
    low_path = current_path.lower()
    low_name = name.lower()
    return any(m in low_path for m in PRIMARY_FOLDER_MARKERS) or \
           any(low_name.startswith(m) for m in PRIMARY_NAME_MARKERS)


def read_google_sheet(sheets_service, file_id, name):
    """Lê TODAS as abas de um Google Sheet como texto (o export CSV pegaria só a primeira)."""
    text = ""
    meta = sheets_service.spreadsheets().get(
        spreadsheetId=file_id, fields="sheets.properties.title"
    ).execute()
    for sheet in meta.get('sheets', []):
        title = sheet['properties']['title']
        resp = sheets_service.spreadsheets().values().get(
            spreadsheetId=file_id, range=title, valueRenderOption='FORMATTED_VALUE'
        ).execute()
        rows = resp.get('values', [])
        text += f"\n## Aba: {title}\n"
        for row in rows:
            text += " | ".join(str(c) for c in row) + "\n"
    return text


def crawl_drive_corpus():
    """Varre o Drive. Retorna (corpus_completo, biblioteca_crua)."""
    print("🌳📚 Build: Conectando ao Google Drive do Afro-Cebrap...")
    credentials, project = google.auth.default(scopes=[
        'https://www.googleapis.com/auth/drive.readonly',
        'https://www.googleapis.com/auth/spreadsheets.readonly',
    ])
    service = build('drive', 'v3', credentials=credentials)
    sheets_service = build('sheets', 'v4', credentials=credentials)

    biblioteca_blocks = []

    def crawl_folder(folder_id, current_path="Raiz"):
        text_accumulated = ""
        try:
            results = service.files().list(
                q=f"'{folder_id}' in parents and trashed = false",
                fields="files(id, name, mimeType)",
                supportsAllDrives=True,
                includeItemsFromAllDrives=True
            ).execute()
        except HttpError as error:
            print(f"❌ Erro ao listar a pasta {current_path}: {error}")
            return text_accumulated

        for item in results.get('files', []):
            mime = item['mimeType']
            name = item['name']

            # Cada item é isolado: um erro (ex.: atalho morto -> 404) não aborta a pasta.
            try:
                if any(marker in name.lower() for marker in EXCLUDE_NAME_MARKERS):
                    print(f"⏭️ Pulado (rascunho/duplicata): {name}")
                    continue

                if mime == 'application/vnd.google-apps.folder':
                    if name in EXCLUDE_FOLDERS:
                        print(f"⏭️ Pulando pasta não-canônica: {current_path}/{name}")
                        continue
                    print(f"📁 Subpasta: {current_path} -> {name}")
                    text_accumulated += crawl_folder(item['id'], current_path=f"{current_path}/{name}")
                    continue

                tag = "FONTE PRIMÁRIA/AUTORITATIVA — " if is_primary_source(name, current_path) else ""
                in_biblioteca = "biblioteca" in current_path.lower()
                block = ""

                if mime == 'application/vnd.google-apps.document':
                    print(f"📄 Google Doc: [{current_path}] {name}")
                    content = service.files().export(fileId=item['id'], mimeType='text/plain').execute()
                    block = f"\n--- {tag}FONTE (Doc): {name} (Caminho: {current_path}) ---\n" + content.decode('utf-8')

                elif mime == 'application/vnd.google-apps.spreadsheet':
                    print(f"📊 Google Sheet: [{current_path}] {name}")
                    block = f"\n--- {tag}FONTE (Sheet): {name} (Caminho: {current_path}) ---\n" + read_google_sheet(sheets_service, item['id'], name)

                elif 'text' in mime or name.endswith(('.md', '.txt')):
                    print(f"📄 Texto: [{current_path}] {name}")
                    content = service.files().get(fileId=item['id'], alt='media').execute()
                    block = f"\n--- {tag}FONTE (texto): {name} (Caminho: {current_path}) ---\n" + content.decode('utf-8')

                elif mime == 'application/pdf' or name.lower().endswith('.pdf'):
                    print(f"📕 PDF: [{current_path}] {name}")
                    pdf_bytes = service.files().get(fileId=item['id'], alt='media').execute()
                    text = ""
                    try:
                        reader = PdfReader(io.BytesIO(pdf_bytes))
                        text = "\n".join((page.extract_text() or "") for page in reader.pages)
                    except Exception as e:
                        print(f"⚠️ Falha ao ler PDF {name}: {e}")
                    if not text.strip():
                        print(f"⚠️ PDF sem texto extraível (possivelmente escaneado): {name}")
                    block = f"\n--- {tag}FONTE (PDF): {name} (Caminho: {current_path}) ---\n" + text

                else:
                    print(f"⏭️ Ignorado (tipo não suportado: {mime}): {name}")
                    continue

                text_accumulated += block
                if in_biblioteca:
                    biblioteca_blocks.append(block)

            except HttpError as error:
                print(f"⚠️ Item pulado por erro ({name}): {error}")
                continue

        return text_accumulated

    corpus = crawl_folder(DRIVE_FOLDER_ID)
    return corpus, "".join(biblioteca_blocks)


def upload_to_gcs(bucket_name, blob_name, text):
    client = storage.Client(project=VERTEX_PROJECT)
    client.bucket(bucket_name).blob(blob_name).upload_from_string(text, content_type="text/markdown")


DISTILL_PROMPT = """\
You are a methodological documentalist for the Afro-Cebrap project on mapping Black \
territories and racialized urban segregation.

Read the project corpus below and write a SINGLE knowledge-base document, in Portuguese, \
that will ground a code-review bot working on the project's segregation-index \
implementation. The bot reviews code, but it must be genuinely fluent in the \
methodological and conceptual foundations behind that code — not merely a list of rules.

This is guidance, not a checklist: let the substance emerge from the sources themselves \
rather than from predefined topics.
- Treat the curated academic library (folder "biblioteca") and the project compendium \
  ("compendio_territorios_negros") as the primary, authoritative sources. Preserve their \
  conceptual depth; do not compress them into shallow bullets.
- Sources vary in maturity and authority. Prefer ratified, consolidated material over \
  loose notes; where sources disagree, surface the disagreement instead of silently \
  choosing; mark anything drawn from draft or "[EM CONSTRUÇÃO]" material as provisional.

Cite sources in parentheses where a point comes from a specific text. Use clear Markdown. \
Let the length follow the material — be thorough where the sources are rich.

CORPUS:
"""


def distill(corpus):
    print(f"🤖 Destilando o corpus com {GEMINI_MODEL} via Vertex AI...")
    client = genai.Client(vertexai=True, project=VERTEX_PROJECT, location=VERTEX_LOCATION)
    response = client.models.generate_content(model=GEMINI_MODEL, contents=DISTILL_PROMPT + corpus)
    return response.text


if __name__ == "__main__":
    corpus, biblioteca_corpus = crawl_drive_corpus()

    if not corpus.strip():
        raise SystemExit("❌ Corpus vazio. Verifique o compartilhamento da pasta com a service account.")

    print(f"📦 Corpus bruto extraído: {len(corpus)} caracteres.")
    digest = distill(corpus)

    stamp = datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
    header = (
        f"<!-- Base de conhecimento do Gui do Bosque — gerada automaticamente. -->\n"
        f"<!-- Gerada em {stamp} a partir da pasta {DRIVE_FOLDER_ID}. -->\n"
        f"<!-- Pode ser editada à mão pela equipe; será sobrescrita no próximo build. -->\n\n"
    )
    os.makedirs("config", exist_ok=True)
    with open(CACHE_PATH, "w", encoding="utf-8") as f:
        f.write(header + digest)
    print(f"✅ Digest gravado em {CACHE_PATH} ({len(digest)} caracteres).")

    # Biblioteca crua -> GCS privado (não vai para o repositório público).
    if biblioteca_corpus.strip():
        if KB_BUCKET:
            upload_to_gcs(KB_BUCKET, LIBRARY_BLOB, biblioteca_corpus)
            print(f"📖 Biblioteca crua ({len(biblioteca_corpus)} caracteres) enviada para gs://{KB_BUCKET}/{LIBRARY_BLOB}")
        else:
            print("⚠️ KB_BUCKET não definido; biblioteca crua NÃO foi persistida.")
    else:
        print("⚠️ Nenhum conteúdo encontrado na pasta 'biblioteca'.")
