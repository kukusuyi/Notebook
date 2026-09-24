"""Run against a native prebuilt server; all data lives in a temporary directory."""
import json
import pathlib
import queue
import socket
import subprocess
import sys
import tempfile
import threading
import urllib.request

binary = str(pathlib.Path(sys.argv[1]).resolve())
processes = []

def start(directory, *args):
    proc = subprocess.Popen(
        [binary, '--data-dir', str(directory), '--parent-stdio', *args],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding='utf-8',
        errors='replace',
    )
    processes.append(proc)
    lines = queue.Queue()
    threading.Thread(target=lambda: lines.put(proc.stdout.readline()), daemon=True).start()
    try:
        line = lines.get(timeout=20)
        if not line:
            raise RuntimeError(proc.stderr.read())
        ready = json.loads(line)
        assert ready['event'] == 'ready'
        return proc, ready
    except BaseException:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        raise

def request(ready, path, body=None, token=''):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(ready['url'] + path, data=json.dumps(body).encode() if body is not None else None, headers=headers)
    with urllib.request.urlopen(req, timeout=10) as response:
        return response.read()

def stop(proc):
    proc.stdin.close()
    assert proc.wait(timeout=15) == 0

try:
    with tempfile.TemporaryDirectory(prefix='notebook-smoke-') as temp:
        data = pathlib.Path(temp) / '中文 数据'
        busy = socket.socket()
        busy.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            busy.bind(('127.0.0.1', 8080))
            busy.listen()
        except OSError:
            busy.close()  # An existing listener exercises the same fallback.
        proc, ready = start(data, '--host', '127.0.0.1')
        assert not ready['url'].endswith(':8080')
        assert b'<html' in request(ready, '/')
        request(ready, '/healthz')
        request(ready, '/api/v1/system/setup', {'token': ready['setup_token'], 'username': 'smoke', 'password': 'test-password-123', 'email': 'smoke@example.test'})
        login = json.loads(request(ready, '/api/v1/auth/login', {'username': 'smoke', 'password': 'test-password-123'}))
        token = login['data']['token']
        request(ready, '/api/v1/wrong-questions', {'subject': 'math', 'source_type': 'manual', 'question_json': {'question_core': '1+1?'}, 'mastery_status': 'unmastered', 'tags': {}}, token)
        duplicate = subprocess.run([binary, '--data-dir', str(data), '--port', '0'], capture_output=True, timeout=10)
        assert duplicate.returncode != 0
        stop(proc)
        busy.close()
        archive = pathlib.Path(temp) / 'backup.zip'
        subprocess.run([binary, '--data-dir', str(data), '--backup', str(archive)], check=True, capture_output=True)
        restored = pathlib.Path(temp) / 'restored'
        subprocess.run([binary, '--data-dir', str(restored), '--restore', str(archive)], check=True, capture_output=True)
        proc, ready = start(restored, '--port', '0')
        assert 'setup_token' not in ready
        assert json.loads(request(ready, '/api/v1/wrong-questions/1', token=token))['data']
        stop(proc)
        print('PASS: embedded UI, occupied-port fallback, Chinese data path, exclusive lock, setup, no-model CRUD, parent EOF shutdown, backup/restore, persistent JWT/data')
finally:
    for proc in processes:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
