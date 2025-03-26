#!/bin/bash
echo "Building server as an executable"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Building For Linux"
    source .venv/bin/activate
    pyinstaller --distpath dist/linux \
            --workpath build/linux \
            --specpath spec/linux \
            --hidden-import=pydantic.deprecated.decorator \
            --hidden-import=app \
            --collect-all chromadb \
            main.py
            
    mkdir dist/linux/main/_internal/server
    mkdir dist/linux/main/_internal/server/public
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Building for MacOS"
    source .venv/bin/activate
    pyinstaller --distpath dist/mac \
                --workpath build/mac \
                --specpath spec/mac \
                --hidden-import=pydantic.deprecated.decorator \
                --hidden-import=app \
                --collect-all chromadb \
                main.py

    mkdir dist/mac/main/_internal/server
    mkdir dist/mac/main/_internal/server/public
elif [[ "$OSTYPE" == "cygwin" || "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "Building for Windows"
    .\.venv\Scripts\Activate
    pyinstaller --distpath dist/windows \
            --workpath build/windows \
            --specpath spec/windows \
            --hidden-import=pydantic.deprecated.decorator \
            --hidden-import=app --hidden-import=pydantic.deprecated.decorator \
            --collect-all chromadb \
            main.py
else
    echo "Unknown OS"
    echo "Build Failed"
fi
