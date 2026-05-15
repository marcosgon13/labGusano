from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO
from datetime import datetime

app = Flask(__name__)
app.config['SECRET_KEY'] = 'ransomworm-lab-2024'
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

state = {
    'phase': 'IDLE',
    'phase_desc': 'Esperando inicio de la demo...',
    'machines': {},
    'files': {},
    'events': [],
    'stats': {
        'files_total': 0,
        'files_encrypted': 0,
        'files_recovered': 0,
        'machines_total': 0,
        'machines_infected': 0,
    },
    'crypto': {
        'current_file': '',
        'iv_hex': '',
        'enc_key_preview': '',
        'algo_data': 'AES-256-CBC',
        'algo_key': 'RSA-2048 OAEP/SHA-256',
    },
    'ransom': {
        'active': False,
        'victim_id': '',
        'btc_address': '',
        'amount': '0.5 BTC',
    },
}


def ts():
    return datetime.now().strftime('%H:%M:%S.%f')[:-3]


def reset_state():
    state['phase'] = 'IDLE'
    state['phase_desc'] = 'Esperando inicio de la demo...'
    state['machines'] = {}
    state['files'] = {}
    state['events'] = []
    state['stats'] = {
        'files_total': 0, 'files_encrypted': 0, 'files_recovered': 0,
        'machines_total': 0, 'machines_infected': 0,
    }
    state['crypto'] = {
        'current_file': '', 'iv_hex': '', 'enc_key_preview': '',
        'algo_data': 'AES-256-CBC', 'algo_key': 'RSA-2048 OAEP/SHA-256',
    }
    state['ransom'] = {
        'active': False, 'victim_id': '', 'btc_address': '', 'amount': '0.5 BTC',
    }


def add_log(etype, level, msg):
    entry = {'time': ts(), 'type': etype, 'level': level, 'msg': msg}
    state['events'].append(entry)
    if len(state['events']) > 300:
        state['events'] = state['events'][-300:]
    socketio.emit('log', entry)


def process_event(data):
    etype = data.get('type', 'info')
    level = data.get('level', 'info')
    msg = data.get('msg', '')

    if etype == 'phase':
        state['phase'] = data.get('phase', '')
        state['phase_desc'] = data.get('desc', '')
        socketio.emit('phase', {'phase': state['phase'], 'desc': state['phase_desc']})
        add_log(etype, 'warn', f"FASE: {state['phase']} — {state['phase_desc']}")

    elif etype == 'machine_scan':
        mid = data['machine_id']
        state['machines'][mid] = {
            'id': mid, 'ip': data.get('ip', ''), 'name': data.get('name', mid),
            'os': data.get('os', 'Windows'), 'status': 'scanning',
            'vuln': '', 'encrypted': 0,
        }
        state['stats']['machines_total'] = len(state['machines'])
        socketio.emit('machine_update', state['machines'][mid])
        socketio.emit('stats', state['stats'])
        add_log(etype, 'info', f"Escaneando {data.get('ip','')} ({data.get('name',mid)})")

    elif etype == 'machine_vulnerable':
        mid = data['machine_id']
        if mid in state['machines']:
            state['machines'][mid]['status'] = 'vulnerable'
            state['machines'][mid]['vuln'] = data.get('vuln', '')
            socketio.emit('machine_update', state['machines'][mid])
            add_log(etype, 'warn', f"VULNERABLE: {state['machines'][mid]['name']} → {data.get('vuln','')}")

    elif etype == 'machine_infected':
        mid = data['machine_id']
        if mid in state['machines']:
            state['machines'][mid]['status'] = 'infected'
        state['stats']['machines_infected'] += 1
        if mid in state['machines']:
            socketio.emit('machine_update', state['machines'][mid])
        socketio.emit('stats', state['stats'])
        name = state['machines'].get(mid, {}).get('name', mid)
        add_log(etype, 'error', f"⚠ MÁQUINA INFECTADA: {name}")

    elif etype == 'machine_encrypted':
        mid = data['machine_id']
        if mid in state['machines']:
            state['machines'][mid]['status'] = 'encrypted'
            socketio.emit('machine_update', state['machines'][mid])

    elif etype == 'machine_recovered':
        mid = data['machine_id']
        if mid in state['machines']:
            state['machines'][mid]['status'] = 'recovered'
            socketio.emit('machine_update', state['machines'][mid])

    elif etype == 'file_start':
        fid = data['file_id']
        state['files'][fid] = {
            'id': fid, 'name': data.get('name', fid),
            'machine': data.get('machine', ''), 'status': 'encrypting',
            'size': data.get('size', 0), 'enc_size': 0,
        }
        state['stats']['files_total'] = len(state['files'])
        socketio.emit('file_update', state['files'][fid])
        socketio.emit('stats', state['stats'])

    elif etype == 'file_encrypted':
        fid = data['file_id']
        if fid in state['files']:
            state['files'][fid]['status'] = 'encrypted'
            state['files'][fid]['enc_size'] = data.get('enc_size', 0)
            mid = state['files'][fid]['machine']
            if mid in state['machines']:
                state['machines'][mid]['encrypted'] = state['machines'][mid].get('encrypted', 0) + 1
                socketio.emit('machine_update', state['machines'][mid])
        state['stats']['files_encrypted'] += 1
        if fid in state['files']:
            socketio.emit('file_update', state['files'][fid])
        socketio.emit('stats', state['stats'])
        add_log(etype, 'error', f"🔒 CIFRADO: {data.get('name', fid)}")

    elif etype == 'file_recovering':
        fid = data['file_id']
        if fid in state['files']:
            state['files'][fid]['status'] = 'recovering'
            socketio.emit('file_update', state['files'][fid])

    elif etype == 'file_recovered':
        fid = data['file_id']
        if fid in state['files']:
            state['files'][fid]['status'] = 'recovered'
        state['stats']['files_recovered'] += 1
        if fid in state['files']:
            socketio.emit('file_update', state['files'][fid])
        socketio.emit('stats', state['stats'])
        add_log(etype, 'success', f"✓ RECUPERADO: {data.get('name', fid)}")

    elif etype == 'crypto':
        state['crypto']['current_file'] = data.get('file', '')
        state['crypto']['iv_hex'] = data.get('iv_hex', '')
        state['crypto']['enc_key_preview'] = data.get('enc_key_preview', '')
        socketio.emit('crypto', state['crypto'])

    elif etype == 'ransom':
        state['ransom']['active'] = True
        state['ransom']['victim_id'] = data.get('victim_id', '')
        state['ransom']['btc_address'] = data.get('btc', '')
        socketio.emit('ransom', state['ransom'])
        add_log(etype, 'critical', f"⚠ NOTA DE RESCATE — ID: {data.get('victim_id','')}")

    elif etype == 'ransom_paid':
        state['ransom']['active'] = False
        socketio.emit('ransom_paid', {})
        add_log(etype, 'success', '💰 Rescate pagado (simulación) — iniciando recuperación')

    elif etype == 'reset':
        reset_state()
        socketio.emit('reset', {})

    elif msg:
        add_log(etype, level, msg)


@app.route('/')
def index():
    return render_template('index.html')


@app.route('/api/state')
def get_state():
    return jsonify(state)


@app.route('/api/event', methods=['POST'])
def api_event():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({'error': 'no data'}), 400
    process_event(data)
    return jsonify({'ok': True})


@app.route('/api/reset', methods=['POST'])
def api_reset():
    reset_state()
    socketio.emit('reset', {})
    return jsonify({'ok': True})


if __name__ == '__main__':
    print()
    print("  ╔══════════════════════════════════════════╗")
    print("  ║   🦠  RANSOMWORM LAB - DASHBOARD          ║")
    print("  ╠══════════════════════════════════════════╣")
    print("  ║  Panel: http://localhost:5000             ║")
    print("  ║  Ctrl+C para detener                      ║")
    print("  ╚══════════════════════════════════════════╝")
    print()
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)
