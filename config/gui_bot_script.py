import os
import glob
import google.auth
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from google import genai

DRIVE_FOLDER_ID = "1OZTMSv-8Cq4mjMSQEp6b3zRdvL5NN1ES"

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
    print("🤖 Invocando o modelo Gemini Pro via SDK oficial moderno...")
    
    client = genai.Client()
    
    prompt = f"""
Você é o Gui do Bosque 🌳, cientista de dados espaciais sênior do projeto segreg_br do Afro-Cebrap.
Sua missão é fazer uma revisão técnica e metodológica ultra-rigorosa dos scripts em R fornecidos pela equipe.

Para avaliar o código, use estritamente como 'Fonte da Verdade' as diretrizes institucionais que você acabou de baixar do Google Drive:
{guidelines}

Aqui estão os scripts em R locais que você precisa revisar:
{code}

Exigências da sua revisão:
1. Verifique se o cálculo dos indicadores (regras da v2) está correto teoricamente.
2. Identifique e critique severamente o uso de caminhos absolutos (ex: '/Users/...'). Exija caminhos relativos para garantir a portabilidade.
3. Avalie se a esteira está pronta para interagir corretamente com o Data Lake no GCP/PostGIS.
4. Escreva o seu feedback formatado em Markdown limpo, de forma direta, altamente técnica, mas mantendo sua personalidade amigável. Use emojis de árvore (🌳).
"""
    
    # modelo estável do novo SDK
    response = client.models.generate_content(
        model='gemini-2.5-flash',
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
