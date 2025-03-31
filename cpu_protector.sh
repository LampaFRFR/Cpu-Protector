#!/bin/bash

# Configurations
TEMP_HIGH=80.0    # Temperature to stop mining
TEMP_LOW=70.0     # Temperature to resume mining
MINING_CMD="xmrig"
STOP_CMD="pkill xmrig"
DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR_WEBHOOK_URL_HERE"
HOSTNAME=$(hostname)

# Function to send messages to Discord
send_discord_message() {
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "{\"content\": \"**[$HOSTNAME]** $1\"}" \
         $DISCORD_WEBHOOK
}

# Function to get the CPU temperature
get_cpu_temp() {
    sensors | grep 'Core 0' | awk '{print $3}' | tr -d '+°C'
}

# Function to compare floating-point numbers
float_compare() {
    echo "$(echo "$1 > $2" | bc)"
}

# Variables
mining_status="stopped"
cooldown_period=60  # Cooldown before checking again after stopping mining
temp_report_interval=600  # Report temperature every 10 minutes
last_temp_report=$(date +%s)

# Monitoring loop
while true; do
    CPU_TEMP=$(get_cpu_temp)
    CPU_TEMP_FLOAT=$(echo "scale=2; $CPU_TEMP" | bc)
    current_time=$(date +%s)

    if [ $(float_compare $CPU_TEMP_FLOAT $TEMP_HIGH) -eq 1 ] && [ "$mining_status" != "stopped" ]; then
        echo "CPU temp is $CPU_TEMP°C. Stopping mining..."
        $STOP_CMD
        send_discord_message ":warning: **CPU Overheat!** Stopping mining. Temp: $CPU_TEMP°C"
        mining_status="stopped"
        sleep $cooldown_period
    fi

    if [ $(float_compare $CPU_TEMP_FLOAT $TEMP_LOW) -eq 0 ] && [ "$mining_status" != "running" ]; then
        echo "CPU temp is $CPU_TEMP°C. Starting mining..."
        $MINING_CMD &
        send_discord_message ":pick: **CPU Cooled Down!** Resuming mining. Temp: $CPU_TEMP°C"
        mining_status="running"
        sleep 10
    fi

    if [ $((current_time - last_temp_report)) -ge $temp_report_interval ]; then
        send_discord_message ":thermometer: **Current CPU Temp:** $CPU_TEMP°C"
        last_temp_report=$current_time
    fi

    sleep 5
done