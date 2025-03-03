import io
import sys
import pylint.lint

class StaticCodeAnalyzer:
    def __init__(self, file_path):
        self.file_path = file_path
        
    def capture_error(self):
        pylint_output = io.StringIO()
        sys.stdout = pylint_output  # Capture Pylint output

        try:
            pylint_opts = ["--disable=all", "--enable=E", self.file_path] # only captrue errors not wornings
            pylint.lint.Run(pylint_opts, exit=False)
        except SystemExit:
            pass  # Pylint sometimes calls sys.exit(), ignore it
        
        sys.stdout = sys.__stdout__  # Reset stdout
        return pylint_output.getvalue().strip()  #Return only the error output 