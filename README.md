# 📄 DigiDoc

DigiDoc é uma aplicação Flutter pensada para gerir documentos pessoais de forma simples, segura e inteligente. Com reconhecimento de documentos via imagem, notificações automáticas de expiração e organização por dossiês, o DigiDoc torna o caos dos papéis em organização digital.

## ✨ Funcionalidades

- **Reconhecimento Inteligente de Documentos**
    - Tira ou envia foto do documento
    - Reconhecimento do tipo de documento com Teachable Machine
    - Área ajustável automaticamente para foco no documento

- **Extração de Texto**
    - OCR integrado para extrair texto pesquisável
    - Pesquisa rápida por palavras-chave

- **Organização por Dossiês**
    - Associa documentos a pessoas ou entidades
    - Cria e edita dossiês à vontade

- **Notificações de Validade**
    - Datas de expiração capturadas automaticamente para documentos predefinidos
    - Alertas personalizáveis para documentos genéricos

- **Segurança**
    - Acesso protegido por código
    - Armazenamento local com `sqflite`

## 🛠️ Tecnologias Utilizadas

- Flutter
- SQLite (sqflite)
- Teachable Machine (classificação de imagens)
- ML Kit Google
- flutter_local_notifications

## 🚀 Como Usar

1. Clone o repositório:
   ```bash
   git clone https://github.com/realbrunoramos/digidoc-repository.git

