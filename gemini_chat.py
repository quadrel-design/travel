import google.generativeai as genai
import os

# Configure the API key
GOOGLE_API_KEY = os.getenv('GOOGLE_API_KEY')  # Get API key from environment variable
if not GOOGLE_API_KEY:
    raise ValueError("Please set the GOOGLE_API_KEY environment variable")

# Initialize the Gemini API
genai.configure(api_key=GOOGLE_API_KEY)

def chat_with_gemini(prompt):
    """
    Send a prompt to Gemini and get a response
    """
    try:
        # Use the Gemini 2.5 Pro Preview model
        model = genai.GenerativeModel('gemini-2.5-pro-preview-03-25')
        
        # Generate content with safety settings
        response = model.generate_content(
            prompt,
            generation_config=genai.types.GenerationConfig(
                temperature=0.7,
                top_p=0.95,
                top_k=40,
                max_output_tokens=2048,
            ),
            safety_settings=[
                {
                    "category": "HARM_CATEGORY_HARASSMENT",
                    "threshold": "BLOCK_MEDIUM_AND_ABOVE"
                },
                {
                    "category": "HARM_CATEGORY_HATE_SPEECH",
                    "threshold": "BLOCK_MEDIUM_AND_ABOVE"
                },
                {
                    "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    "threshold": "BLOCK_MEDIUM_AND_ABOVE"
                },
                {
                    "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                    "threshold": "BLOCK_MEDIUM_AND_ABOVE"
                }
            ]
        )
        return response.text
    except Exception as e:
        return f"Error: {str(e)}"

def main():
    print("Welcome to Gemini Chat! (Type 'quit' to exit)")
    print("-" * 50)
    
    while True:
        user_input = input("\nYou: ")
        if user_input.lower() == 'quit':
            print("\nGoodbye!")
            break
            
        response = chat_with_gemini(user_input)
        print("\nGemini:", response)
        print("-" * 50)

if __name__ == "__main__":
    main() 