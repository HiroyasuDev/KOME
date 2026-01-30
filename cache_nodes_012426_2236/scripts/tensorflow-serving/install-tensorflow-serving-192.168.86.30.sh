#!/usr/bin/env bash
# Install and run TensorFlow Serving on CORE GPU 192.168.86.30
# REST 8501, gRPC 8500, bound to 0.0.0.0 so OKOME at .25 can reach it.
# Run ON 192.168.86.30 (Linux/WSL2). See docs/GPU_HOST_TENSORFLOW_INTEGRATION.md.

set -euo pipefail

TF_REST_PORT="${TF_REST_PORT:-8501}"
TF_GRPC_PORT="${TF_GRPC_PORT:-8500}"
MODEL_BASE_PATH="${MODEL_BASE_PATH:-/opt/okome-tf-serving/models}"
MODEL_NAME="${MODEL_NAME:-my_model}"

echo "TensorFlow Serving: gRPC ${TF_GRPC_PORT}, REST ${TF_REST_PORT}, bind 0.0.0.0"
echo "Model base path: ${MODEL_BASE_PATH}"

# Option 1: Docker (recommended if Docker + GPU available)
if command -v docker &>/dev/null; then
  echo "Using Docker..."
  mkdir -p "${MODEL_BASE_PATH}"
  # Placeholder: copy your SavedModel to ${MODEL_BASE_PATH}
  # Example run (adjust model path and config):
  # docker run -d --gpus all -p ${TF_GRPC_PORT}:8500 -p ${TF_REST_PORT}:8501 \
  #   -v "${MODEL_BASE_PATH}:/models" \
  #   -e MODEL_NAME="${MODEL_NAME}" \
  #   tensorflow/serving:latest-gpu
  echo "Docker detected. Example:"
  echo "  docker run -d --gpus all -p ${TF_GRPC_PORT}:8500 -p ${TF_REST_PORT}:8501 \\"
  echo "    -v ${MODEL_BASE_PATH}:/models \\"
  echo "    -e MODEL_NAME=${MODEL_NAME} \\"
  echo "    tensorflow/serving:latest-gpu"
  echo "Then: curl -s http://127.0.0.1:${TF_REST_PORT}/v1/models"
  exit 0
fi

# Option 2: Native tensorflow_model_server (apt)
if ! command -v tensorflow_model_server &>/dev/null; then
  echo "Installing TensorFlow Serving (apt)..."
  echo "deb [arch=amd64] http://storage.googleapis.com/tensorflow-serving-apt stable tensorflow-model-server tensorflow-model-server-universal" | sudo tee /etc/apt/sources.list.d/tensorflow-serving.list
  curl -fsSL https://storage.googleapis.com/tensorflow-serving-apt/tensorflow-serving.release.pub.gpg | sudo gpg --dearmor -o /usr/share/keyrings/tensorflow-serving.gpg
  sudo apt-get update && sudo apt-get install -y tensorflow-model-server
fi

sudo mkdir -p "${MODEL_BASE_PATH}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
CONFIG_EXAMPLE="${SCRIPT_DIR}/../../configs/tensorflow-serving/model_config_file.example"
if [[ -f "${CONFIG_EXAMPLE}" ]]; then
  sudo cp "${CONFIG_EXAMPLE}" "${MODEL_BASE_PATH}/models.config" 2>/dev/null || true
fi

echo "Start with:"
echo "  tensorflow_model_server --port=${TF_GRPC_PORT} --rest_api_port=${TF_REST_PORT} \\"
echo "    --model_name=${MODEL_NAME} --model_base_path=${MODEL_BASE_PATH}"
echo "Or install systemd unit: configs/tensorflow-serving/tensorflow-serving.service"
echo "Verification: curl -s http://192.168.86.30:${TF_REST_PORT}/v1/models"
