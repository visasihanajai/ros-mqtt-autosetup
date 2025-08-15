#!/bin/bash
set -e

# ===== CONFIG =====
ROS_DIR="$HOME/ros-mqtt"
ROS_IMAGE="ros:noetic-ros-core"

# ===== STEP 1: Find IOTstack network =====
IOTSTACK_NET=$(docker network ls --format '{{.Name}}' | grep -i iotstack | head -n 1)
if [ -z "$IOTSTACK_NET" ]; then
    echo "❌ ไม่พบ network ของ IOTstack"
    echo "   โปรดสร้าง network หรือระบุชื่อด้วยตนเองในสคริปต์นี้"
    exit 1
fi
echo "✅ พบ IOTstack network: $IOTSTACK_NET"

# ===== STEP 2: Install Docker & Compose =====
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
fi
if ! command -v docker compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
fi

# ===== STEP 3: Create ROS Project Folder =====
mkdir -p $ROS_DIR
cd $ROS_DIR

# ===== STEP 4: Create docker-compose.yml =====
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  ros:
    image: $ROS_IMAGE
    container_name: ros_core
    restart: unless-stopped
    command: >
      bash -c "
      apt-get update &&
      apt-get install -y ros-noetic-rosbridge-server ros-noetic-mqtt-bridge &&
      roscore"
    networks:
      - iot_net

  rosbridge:
    image: $ROS_IMAGE
    container_name: ros_bridge
    restart: unless-stopped
    command: >
      bash -c "
      apt-get update &&
      apt-get install -y ros-noetic-rosbridge-server &&
      source /opt/ros/noetic/setup.bash &&
      roslaunch rosbridge_server rosbridge_websocket.launch"
    networks:
      - iot_net
    depends_on:
      - ros

  mqtt_bridge:
    image: $ROS_IMAGE
    container_name: ros_mqtt_bridge
    restart: unless-stopped
    environment:
      - MQTT_HOST=mqtt-broker
      - MQTT_PORT=1883
    command: >
      bash -c "
      apt-get update &&
      apt-get install -y ros-noetic-mqtt-bridge &&
      source /opt/ros/noetic/setup.bash &&
      rosrun mqtt_bridge mqtt_bridge_node.py"
    networks:
      - iot_net
    depends_on:
      - ros

networks:
  iot_net:
    external: true
    name: $IOTSTACK_NET
EOF

# ===== STEP 5: Launch ROS Stack =====
docker compose up -d

echo "✅ ติดตั้ง ROS + rosbridge + MQTT bridge เรียบร้อย"
echo "   เชื่อมกับ IOTstack network: $IOTSTACK_NET"
echo "   ใช้คำสั่ง docker ps เพื่อตรวจสอบ container"
