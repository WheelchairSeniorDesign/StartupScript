#!/bin/bash

source  ~/.bashrc

source /opt/ros/humble/setup.bash
source ~/ros2_ws/install/setup.bash
source ~/ws_livox/install/setup.bash
source ~/microros_ws/install/setup.bash
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib #used for the lidar
export PATH="/home/bad/.local/bin:$PATH"
export CUDA_HOME=/usr/local/cuda
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64:/usr/local/cuda/extras/CUPTI/lib64
export PATH=$PATH:$CUDA_HOME/bin
. "$HOME/.cargo/env"
#source /opt/ros/noetic/setup.bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# Track PIDs
PIDS=()


# Function to watch for /dev/ttyACM* devices and start micro_ros_agent
watch_and_start_agents() {
  declare -A seen
  while true; do
    for dev in /dev/ttyACM*; do
      [[ -e "$dev" ]] || continue
      if [[ -z "${seen[$dev]}" ]]; then
        echo "Starting micro_ros_agent for $dev"
        ros2 run micro_ros_agent micro_ros_agent serial --dev "$dev" -b 115200 &
        seen[$dev]=1
        # Stop after starting 2 agents
        if [ "${#seen[@]}" -ge 2 ]; then
          return
        fi
      fi
    done
    sleep 1
  done
}

# Cleanup function on Ctrl+C
cleanup() {
  echo "Caught Ctrl+C, killing child processes..."
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null
  done
  kill 0  # kill all child processes in this process group
  exit 0
}

trap cleanup SIGINT

# Start processes and track their PIDs
watch_and_start_agents &
PIDS+=($!)

ros2 run wheelchair_code_module wheelchair &
PIDS+=($!)

ros2 run wheelchair_code_module obstacle_publisher_node &
PIDS+=($!)

ros2 run wheelchair_code_module temp_monitor &
PIDS+=($!)

ros2 launch livox_ros_driver2 rviz_MID360_launch.py &
PIDS+=($!)

(cd ~/Frontend/test-app && npm start) &
PIDS+=($!)

(cd ~/Frontend/electron-communication && node middle_man.js) &
PIDS+=($!)

# Wait for all background jobs
wait
