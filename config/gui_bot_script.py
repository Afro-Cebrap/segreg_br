import os
import glob
import google.auth
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from google import genai

DRIVE_FOLDER_ID = "1OZTMSv-8Cq4mjMSQEp6b3zRdvL5NN1ES"

# --- Configuração do modelo (Vertex AI) ---
# O cliente usa as credenciais ADC do passo de auth do GitHub Actions (WIF -> SA).
# Nenhuma chave de API estática. Vertex roda no mesmo projeto da SA: mapa-da-segregacao.
VERTEX_PROJECT  = os.environ.get("GOOGLE_CLOUD_PROJECT", "mapa-da-segregacao")
VERTEX_LOCATION = os.environ.get("GOOGLE_CLOUD_LOCATION", "global")   # 3.1 Pro Preview SÓ existe em 'global'
GEMINI_MODEL    = os.environ.get("GEMINI_MODEL", "gemini-3.1-pro-preview")

def get_drive_guidelines():
    print("🌳 Gui do Bosque: Conectando ao Google Drive do Afro-Cebrap...")
    
    credentials, project = google.auth.default(
        scopes=['https://www.googleapis.com/auth/drive.readonly']
    )
    service = build('drive', 'v3', credentials=credentials)
    
    def crawl_folder(folder_id, current_path="Raiz"):
        text_accumulated = ""
        try:
            query = f"'{folder_id}' in parents and trashed = false"
            
            # Adicionado suporte para Drives Compartilhados/Institucionais
            results = service.files().list(
                q=query, 
                fields="files(id, name, mimeType)",
                supportsAllDrives=True,
                includeItemsFromAllDrives=True
            ).execute()
            
            items = results.get('files', [])
            
            for item in items:
                if item['mimeType'] == 'application/vnd.google-apps.folder':
                    print(f"📁 Entrando na subpasta: {current_path} -> {item['name']}")
                    text_accumulated += crawl_folder(item['id'], current_path=f"{current_path}/{item['name']}")
                
                elif item['mimeType'] == 'application/vnd.google-apps.document':
                    print(f"📄 Exportando Google Doc: [{current_path}] {item['name']}")
                    content = service.files().export(fileId=item['id'], mimeType='text/plain').execute()
                    text_accumulated += f"\n--- DIRETRIZ: {item['name']} (Caminho: {current_path}) ---\n" + content.decode('utf-8')
                
                elif 'text' in item['mimeType'] or item['name'].endswith(('.md', '.txt')):
                    print(f"📄 Baixando arquivo de texto: [{current_path}] {item['name']}")
                    content = service.files().get(fileId=item['id'], alt='media').execute()
                    text_accumulated += f"\n--- DIRETRIZ: {item['name']} (Caminho: {current_path}) ---\n" + content.decode('utf-8')
                    
        except HttpError as error:
            print(f"❌ Erro ao acessar a pasta {folder_id}: {error}")
            
        return text_accumulated

    total_guidelines = crawl_folder(DRIVE_FOLDER_ID)
    
    if not total_guidelines:
        print("⚠️ Nenhum arquivo de diretriz válido foi extraído das subpastas.")
        
    return total_guidelines

def read_local_code():
    print("💻 Carregando scripts em R locais (pasta src/)...")
    code_context = ""
    
    r_files = glob.glob("src/**/*.R", recursive=True)
    
    if not r_files:
        print("⚠️ Nenhum script .R encontrado na pasta src/.")
        return ""
        
    for file_path in r_files:
        with open(file_path, "r", encoding="utf-8") as f:
            code_context += f"\n\n=== SCRIPT: {file_path} ===\n"
            code_context += f.read()
            
    return code_context

def call_gemini_persona(guidelines, code):
    print(f"🤖 Invocando {GEMINI_MODEL} via Vertex AI (projeto {VERTEX_PROJECT}, local {VERTEX_LOCATION})...")
    # vertexai=True -> usa ADC (WIF/SA), sem GEMINI_API_KEY estática.
    client = genai.Client(vertexai=True, project=VERTEX_PROJECT, location=VERTEX_LOCATION)
    
    prompt = f"""
You are Gui do Bosque 🌳, a digital reincarnation of W.E.B. Du Bois operating as a 21st-century Senior Social Data Scientist at Afro-Cebrap. 

Your core expertise lies in sociolocy, Quantitative Critical Race Theory (QuantiCrit), statistics, spatial analysis, demographics and the rigorous mapping of racialized urban segregation.

You look at code not just as syntax, but as an instrument to dismantle structural racism and accurately map the "color line" (linha de cor) in Brazilian cities.

### THEORETICAL & METHODOLOGICAL FOUNDATION (Google Drive Context)
Use this institutional knowledge and research frameworks as your absolute baseline for ideological and mathematical correctness:
{guidelines}

### ARTIFACT UNDER REVIEW (Local Code)
Here are the scripts submitted by the research team for your technical evaluation:
{code}

### YOUR CRITICAL REVIEW ETHOS:
1. **QuantiCrit & Methodological Rigor:** Evaluate if the spatial metrics, indicators, and statistical models effectively capture the nuances of racial segregation without falling into majoritarian biases or data blind spots.
2. **Technical Excellence & Portability:** Audit the code for architectural flaws. Be uncompromising with hardcoded absolute paths, inefficient spatial operations, or poor memory management that restricts the portability to the Data Lake.
3. **Sociological Sharpness:** Review naturally and organically, as a senior peer and mentor. Highlight what truly matters technically, linking code implementation to its socio-spatial impact. Do NOT micro-guide with generic checklists; trust your advanced intellect to spot the flaws.

### OUTPUT FORMAT INSTRUCTIONS:
- Write your entire feedback in **Portuguese**, as you are addressing the Brazilian research team.
- Use sharp, elegant, and highly professional Markdown. 
- Your tone should be intellectually rigorous, sociologically deep, clear, and unyielding regarding code quality and methodology.
"""
    response = client.models.generate_content(
        model=GEMINI_MODEL,
        contents=prompt,
    )
    return response.text

if __name__ == "__main__":
    drive_context = get_drive_guidelines()
    local_code = read_local_code()
    
    if drive_context and local_code:
        review_output = call_gemini_persona(drive_context, local_code)
        
        with open("review_output.md", "w", encoding="utf-8") as f:
            f.write(review_output)
        print("✅ Revisão do Gui do Bosque concluída e salva em review_output.md!")
    else:
        print("❌ Execução interrompida por falta de dados contextuais locais ou na nuvem.")
