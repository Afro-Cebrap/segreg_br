import os
import io
import datetime
import google.auth
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from google import genai
from pypdf import PdfReader

DRIVE_FOLDER_ID = "1OZTMSv-8Cq4mjMSQEp6b3zRdvL5NN1ES"
CACHE_PATH = "config/guidelines_cache.md"

# --- Configuração do modelo (Vertex AI) ---
VERTEX_PROJECT  = os.environ.get("GOOGLE_CLOUD_PROJECT", "mapa-da-segregacao")
VERTEX_LOCATION = os.environ.get("GOOGLE_CLOUD_LOCATION", "global")
GEMINI_MODEL    = os.environ.get("GEMINI_MODEL", "gemini-3.1-pro-preview")


def crawl_drive_corpus():
    """Varre o Drive recursivamente e extrai texto de Google Docs, .md/.txt e PDFs."""
    print("🌳📚 Build: Conectando ao Google Drive do Afro-Cebrap...")
    credentials, project = google.auth.default(
        scopes=['https://www.googleapis.com/auth/drive.readonly']
    )
    service = build('drive', 'v3', credentials=credentials)

    def crawl_folder(folder_id, current_path="Raiz"):
        text_accumulated = ""
        try:
            query = f"'{folder_id}' in parents and trashed = false"
            results = service.files().list(
                q=query,
                fields="files(id, name, mimeType)",
                supportsAllDrives=True,
                includeItemsFromAllDrives=True
            ).execute()

            for item in results.get('files', []):
                mime = item['mimeType']
                name = item['name']

                if mime == 'application/vnd.google-apps.folder':
                    print(f"📁 Subpasta: {current_path} -> {name}")
                    text_accumulated += crawl_folder(item['id'], current_path=f"{current_path}/{name}")

                elif mime == 'application/vnd.google-apps.document':
                    print(f"📄 Google Doc: [{current_path}] {name}")
                    content = service.files().export(fileId=item['id'], mimeType='text/plain').execute()
                    text_accumulated += f"\n--- FONTE (Doc): {name} (Caminho: {current_path}) ---\n" + content.decode('utf-8')

                elif 'text' in mime or name.endswith(('.md', '.txt')):
                    print(f"📄 Texto: [{current_path}] {name}")
                    content = service.files().get(fileId=item['id'], alt='media').execute()
                    text_accumulated += f"\n--- FONTE (texto): {name} (Caminho: {current_path}) ---\n" + content.decode('utf-8')

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
                    text_accumulated += f"\n--- FONTE (PDF): {name} (Caminho: {current_path}) ---\n" + text

                else:
                    print(f"⏭️ Ignorado (tipo não suportado: {mime}): {name}")

        except HttpError as error:
            print(f"❌ Erro ao acessar a pasta {folder_id}: {error}")

        return text_accumulated

    return crawl_folder(DRIVE_FOLDER_ID)


DISTILL_PROMPT = """\
Você é um documentalista metodológico do projeto de mapeamento de territórios negros e \
segregação urbana racializada do Afro-Cebrap. A seguir está o corpus completo de textos \
institucionais e acadêmicos do projeto (diretrizes, papers, notas técnicas).

Produza UM ÚNICO documento de referência conciso, em português, com as REGRAS OPERATIVAS \
que um revisor de código precisa conhecer para auditar a implementação dos índices de \
segregação. Foque em decisões acionáveis e verificáveis, não em resumo narrativo:

- definições e convenções de cada índice (Dissimilaridade, Theil/H, Variância/V, \
  exposição/isolamento, etc.) e as relações matemáticas entre eles;
- convenções de agrupamento racial (ex.: preto+pardo) e o racional empírico;
- tratamento de dados ausentes (NA), viés de amostra pequena e o problema da unidade \
  de área modificável (MAUP);
- padrões de engenharia e reprodutibilidade exigidos pelo projeto.

Seja denso e direto. Cite a fonte entre parênteses quando uma regra vier de um texto \
específico. Use Markdown com seções claras. Este documento será a base de conhecimento \
de um bot revisor, então priorize precisão sobre completude.

CORPUS:
"""


def distill(corpus):
    print(f"🤖 Destilando o corpus com {GEMINI_MODEL} via Vertex AI...")
    client = genai.Client(vertexai=True, project=VERTEX_PROJECT, location=VERTEX_LOCATION)
    response = client.models.generate_content(
        model=GEMINI_MODEL,
        contents=DISTILL_PROMPT + corpus,
    )
    return response.text


if __name__ == "__main__":
    corpus = crawl_drive_corpus()

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

    print(f"✅ Base de conhecimento gravada em {CACHE_PATH} ({len(digest)} caracteres destilados).")
