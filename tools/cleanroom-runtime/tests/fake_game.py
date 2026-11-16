"""Real child-process fixture for transport/lifecycle tests; never represents Minecraft evidence."""
import json
from pathlib import Path
import sys
import threading
import time

mode = sys.argv[1]
Path('child-pid.txt').write_text(str(__import__('os').getpid()))
if mode == 'job-parent':
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from windows_job import Job
    job = Job()
    child = job.start([sys.executable, '-c', 'import time; time.sleep(60)'])
    Path('job-child-pid.txt').write_text(str(child.pid))
    time.sleep(60)
    sys.exit(0)
if mode == 'crash':
    sys.exit(17)
if mode == 'hang':
    time.sleep(60)
    sys.exit(0)
if mode == 'server':
    print('Done (0.1s)!', flush=True)
    for line in sys.stdin:
        if line.strip() == 'stop':
            sys.exit(0)
        print('ANSWER ' + line.strip(), flush=True)
else:
    inbox = Path('config/devtool/client-inbox')
    inbox.mkdir(parents=True, exist_ok=True)
    if mode != 'stale':
        (inbox / 'status.json').write_text(json.dumps({'startedAtMillis': int(time.time() * 1000)}))
    while True:
        for path in inbox.glob('*.req'):
            text = path.read_text().strip()
            reply = {'id': path.stem if mode != 'wrong-id' else 'someone-else', 'request': text, 'outcome': 'done'}
            temp = path.with_suffix('.tmp')
            temp.write_text(json.dumps(reply))
            temp.rename(path.with_suffix('.result.json'))
            path.unlink()
            if text == 'quit':
                time.sleep(.25)
                sys.exit(0)
        time.sleep(.025)
