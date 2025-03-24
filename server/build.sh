echo "Building server as an executable"
source .venv/bin/activate
pyinstaller --hidden-import=pydantic.deprecated.decorator \
            --hidden-import=app --hidden-import=pydantic.deprecated.decorator \
            --collect-all chromadb \
            main.py
echo "Creating server director and public directory"
mkdir dist/main/_internal/server
mkdir dist/main/_internal/server/public