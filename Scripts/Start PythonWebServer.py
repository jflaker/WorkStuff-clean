import os
import subprocess

# Change the working directory
os.chdir(os.environ.get('SLIDESHOW_DIR', os.path.dirname(os.path.abspath(__file__))))


# Open a new command prompt window, run the http.server command on port 80, then close the window upon termination
subprocess.Popen(['start', 'cmd', '/k', 'python -m http.server 80 ^& exit'], shell=True)


import os
import subprocess

# Change the working directory
os.chdir(os.environ.get('SLIDESHOW_DIR', os.path.dirname(os.path.abspath(__file__))))

# Open a new command prompt window, run the http.server command on port 80, then close the window upon termination
subprocess.Popen(['cmd', '/c', 'start', 'cmd', '/k', 'python -m http.server 80 ^& exit'], shell=True)