import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from io import StringIO
from pathlib import Path

import pandas as pd
import streamlit as st


SSH_CONNECT_TIMEOUT = 5
SSH_REMOTE_TIMEOUT = 12
SSH_CMD_TIMEOUT = SSH_CONNECT_TIMEOUT + SSH_REMOTE_TIMEOUT + 5
SSH_CONFIG_PATH = Path.home() / ".ssh" / "config"
DEFAULT_SHORT_HOSTS = tuple(f"zxcpu{index}" for index in range(1, 6))


def display_name(host):
    return host.split(".", 1)[0].upper()


def discover_ssh_hosts():
    try:
        contents = SSH_CONFIG_PATH.read_text(encoding="utf-8")
    except OSError:
        return []

    hosts = []
    seen = set()
    for raw_line in contents.splitlines():
        line = raw_line.split("#", 1)[0].strip()
        fields = line.split()
        if not fields or fields[0].lower() != "host":
            continue
        for host in fields[1:]:
            if any(marker in host for marker in "*?!"):
                continue
            identity = host.lower()
            if identity not in seen:
                seen.add(identity)
                hosts.append(host)
    return hosts


def resolve_default_hosts():
    configured_hosts = discover_ssh_hosts()
    by_short_name = {}
    for host in configured_hosts:
        short_name = host.split(".", 1)[0].lower()
        by_short_name.setdefault(short_name, host)
        if host.lower() == short_name:
            by_short_name[short_name] = host

    return [
        by_short_name.get(short_name, short_name)
        for short_name in DEFAULT_SHORT_HOSTS
    ]


def get_gpu_status(host):
    remote_script = f"""
    export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
    REMOTE_TIMEOUT={SSH_REMOTE_TIMEOUT}

    timeout ${{REMOTE_TIMEOUT}}s nvidia-smi --query-gpu=index,uuid,name,memory.used,memory.total,utilization.gpu,temperature.gpu --format=csv,noheader,nounits
    echo "|||SPLIT|||"

    timeout ${{REMOTE_TIMEOUT}}s nvidia-smi --query-compute-apps=gpu_uuid,pid,used_memory,process_name --format=csv,noheader,nounits
    echo "|||SPLIT|||"

    pids=$(timeout ${{REMOTE_TIMEOUT}}s nvidia-smi --query-compute-apps=pid --format=csv,noheader | paste -sd, -)
    if [ -n "$pids" ]; then
        timeout ${{REMOTE_TIMEOUT}}s ps -o pid=,user= -p "$pids"
    fi
    """

    command = [
        "ssh",
        "-o",
        "BatchMode=yes",
        "-o",
        f"ConnectTimeout={SSH_CONNECT_TIMEOUT}",
        "-o",
        "ConnectionAttempts=1",
        "-o",
        "ServerAliveInterval=5",
        "-o",
        "ServerAliveCountMax=1",
        "-o",
        "ControlMaster=auto",
        "-o",
        "ControlPersist=60",
        "-o",
        "ControlPath=/tmp/gpuweb-%C",
        "-o",
        "ClearAllForwardings=yes",
        "-o",
        "LogLevel=ERROR",
        host,
        f"bash -c '{remote_script}'",
    ]

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=SSH_CMD_TIMEOUT,
        )
        if result.returncode != 0:
            message = result.stderr.strip() or f"SSH exited with {result.returncode}"
            return host, None, None, None, message

        parts = result.stdout.strip().split("|||SPLIT|||")
        if len(parts) >= 3:
            return host, parts[0].strip(), parts[1].strip(), parts[2].strip(), None
        return host, parts[0].strip(), "", "", None
    except subprocess.TimeoutExpired:
        return host, None, None, None, f"Timeout after {SSH_CMD_TIMEOUT}s"
    except OSError as error:
        return host, None, None, None, str(error)


def parse_data(gpu_csv, process_csv, user_text):
    try:
        gpu_columns = [
            "idx",
            "uuid",
            "name",
            "mem_used",
            "mem_total",
            "util_gpu",
            "temp",
        ]
        gpu_data = pd.read_csv(
            StringIO(gpu_csv),
            header=None,
            names=gpu_columns,
            skipinitialspace=True,
        )
        gpu_data["uuid"] = gpu_data["uuid"].astype(str).str.strip()
    except Exception:
        gpu_data = pd.DataFrame()

    try:
        if not process_csv:
            process_data = pd.DataFrame()
        else:
            process_columns = ["gpu_uuid", "pid", "mem_used", "process_name"]
            process_data = pd.read_csv(
                StringIO(process_csv),
                header=None,
                names=process_columns,
                skipinitialspace=True,
            )
            process_data["process_name"] = (
                process_data["process_name"].astype(str).str.strip()
            )
            process_data["gpu_uuid"] = (
                process_data["gpu_uuid"].astype(str).str.strip()
            )
            process_data["pid"] = pd.to_numeric(
                process_data["pid"], errors="coerce"
            )
            process_data = process_data.dropna(subset=["pid"])
            process_data["pid"] = process_data["pid"].astype(int)
    except Exception:
        process_data = pd.DataFrame()

    try:
        if not user_text:
            user_data = pd.DataFrame(columns=["pid", "user"])
        else:
            user_data = pd.read_csv(
                StringIO(user_text),
                sep=r"\s+",
                names=["pid", "user"],
                header=None,
            )
            user_data["pid"] = pd.to_numeric(user_data["pid"], errors="coerce")
            user_data = user_data.dropna(subset=["pid"])
            user_data["pid"] = user_data["pid"].astype(int)
    except Exception:
        user_data = pd.DataFrame(columns=["pid", "user"])

    if not process_data.empty:
        if not user_data.empty:
            process_data = pd.merge(process_data, user_data, on="pid", how="left")
            process_data["user"] = process_data["user"].fillna("Unknown")
        else:
            process_data["user"] = "Unknown"

        if not gpu_data.empty:
            uuid_map = dict(zip(gpu_data["uuid"], gpu_data["idx"]))
            process_data["gpu_idx"] = process_data["gpu_uuid"].map(uuid_map)

    return gpu_data, process_data


def summarize_host(host, gpu_data, error):
    total = len(gpu_data)
    free_data = (
        gpu_data[gpu_data["mem_used"] < 500]
        if not gpu_data.empty
        else pd.DataFrame()
    )
    free_count = len(free_data)
    free_ids = "-"
    if not free_data.empty:
        free_ids = "GPU " + ", ".join(str(int(index)) for index in free_data["idx"])

    used_lines = []
    if not gpu_data.empty:
        for _, row in gpu_data[gpu_data["mem_used"] >= 500].iterrows():
            used_lines.append(
                f"GPU {int(row['idx'])}: "
                f"{int(float(row['mem_used']) / 1024)}G / "
                f"{int(float(row['mem_total']) / 1024)}G"
            )

    return {
        "Server": display_name(host),
        "Free": f"{free_count} / {total}",
        "Free GPUs": free_ids,
        "Used GPUs": "\n".join(used_lines) or "-",
        "Status": (
            "🔴 Down"
            if error
            else ("🟢 OK" if free_count > 0 else "🟡 Full")
        ),
    }


def render_gpu_details(gpu_data, process_data, error):
    if error:
        st.error(error)
        return
    if gpu_data.empty:
        st.warning("No GPU Info")
        return

    for _, row in gpu_data.iterrows():
        try:
            gpu_index = int(row["idx"])
            memory_used = float(row["mem_used"])
            memory_total = float(row["mem_total"])
            utilization = float(row["util_gpu"])
            temperature = int(row["temp"])
        except (TypeError, ValueError):
            continue

        ratio = memory_used / memory_total if memory_total > 0 else 0
        gpu_name = (
            str(row["name"])
            .replace("NVIDIA ", "")
            .replace("GeForce ", "")
            .replace("RTX ", "")
        )

        with st.container(border=True):
            name_column, temperature_column = st.columns([7, 3])
            name_column.write(f"**GPU {gpu_index}**: {gpu_name}")
            color = "red" if temperature > 80 else "grey"
            temperature_column.markdown(f":{color}[{temperature}°C]")
            st.progress(
                ratio,
                text=f"RAM: {int(memory_used)} / {int(memory_total)} MB",
            )
            st.metric(
                "Utility",
                f"{int(utilization)}%",
                label_visibility="collapsed",
            )

            if process_data.empty or "gpu_idx" not in process_data.columns:
                st.caption("Idle")
                continue

            gpu_processes = process_data[
                process_data["gpu_idx"] == gpu_index
            ].copy()
            if gpu_processes.empty:
                st.caption("No active processes")
                continue

            gpu_processes["process_name"] = gpu_processes["process_name"].apply(
                lambda value: value.split("/")[-1] if "/" in value else value
            )
            display_data = gpu_processes[
                ["user", "pid", "mem_used", "process_name"]
            ]
            display_data.columns = ["User", "PID", "Mem", "Proc"]
            st.dataframe(
                display_data,
                hide_index=True,
                use_container_width=True,
            )


def render_availability(stats):
    headers = ["Server", "Free", "Free GPUs", "Used GPUs", "Status"]
    rows = [
        "| " + " | ".join(headers) + " |",
        "|" + " | ".join(["---"] * len(headers)) + "|",
    ]
    for stat in stats:
        values = [
            str(stat.get("Server", "")),
            str(stat.get("Free", "")),
            str(stat.get("Free GPUs", "")),
            str(stat.get("Used GPUs", "-")).replace("\n", "<br>"),
            str(stat.get("Status", "")),
        ]
        rows.append("| " + " | ".join(values) + " |")
    st.markdown("\n".join(rows), unsafe_allow_html=True)


st.set_page_config(
    page_title="GPU Cluster",
    layout="wide",
    page_icon="⚡",
    initial_sidebar_state="expanded",
)

st.markdown(
    """
<style>
    .stProgress > div > div > div > div { background-color: #00CC96; }
    div[data-testid="stMetricValue"] { font-size: 1.2rem; }
    [data-testid="stSidebar"] {
        min-width: 480px;
        width: 480px;
    }
    div[data-testid="block-container"],
    .block-container {
        max-width: 100% !important;
        padding-left: 2rem;
        padding-right: 2rem;
        margin-left: 0 !important;
        margin-right: auto !important;
    }
</style>
""",
    unsafe_allow_html=True,
)

selected_hosts = resolve_default_hosts()

with st.sidebar:
    st.subheader("📊 Availability")
    availability_placeholder = st.empty()
    st.caption("Free = Memory < 500 MiB")

st.title("⚡ GPU Cluster Monitor")

with ThreadPoolExecutor(max_workers=min(len(selected_hosts), 8)) as executor:
    results = list(executor.map(get_gpu_status, selected_hosts))

stats = []
for row_start in range(0, len(results), 3):
    columns = st.columns(3)
    for column, result in zip(columns, results[row_start : row_start + 3]):
        host, gpu_raw, process_raw, user_raw, error = result
        gpu_data, process_data = pd.DataFrame(), pd.DataFrame()
        if not error and gpu_raw:
            gpu_data, process_data = parse_data(gpu_raw, process_raw, user_raw)

        stats.append(summarize_host(host, gpu_data, error))
        with column:
            st.subheader(f"🖥️ {display_name(host)}")
            with st.expander("GPU Details", expanded=False):
                render_gpu_details(gpu_data, process_data, error)

with availability_placeholder.container():
    render_availability(stats)

st.caption(f"Last updated: {time.strftime('%H:%M:%S')}")
time.sleep(5)
st.rerun()
