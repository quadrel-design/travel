import os
import google.generativeai as genai

# Configure the API key
GOOGLE_API_KEY = os.getenv('GOOGLE_API_KEY')
if not GOOGLE_API_KEY:
    raise ValueError("Please set the GOOGLE_API_KEY environment variable")

# Initialize the Gemini API
genai.configure(api_key=GOOGLE_API_KEY)

# List all available models
print("Available Models:")
print("-" * 50)
for model in genai.list_models():
    print(f"Name: {model.name}")
    print(f"Display Name: {model.display_name}")
    print("-" * 50) 