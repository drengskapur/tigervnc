#!/usr/bin/env python3
import subprocess
import time
import argparse
import json
import os
from datetime import datetime

def run_benchmark(resolution="1024x768", color_depth=24, operations=5):
    """Run benchmarks for TigerVNC"""
    results = {
        "vnc_type": "tiger",
        "resolution": resolution,
        "color_depth": color_depth,
        "timestamp": datetime.now().isoformat(),
        "metrics": {}
    }
    
    # Create test content
    subprocess.run([
        "convert", "-size", resolution, "gradient:blue-red", "/tmp/test_image.png"
    ])
    
    # Start Xvfb for virtual display
    xvfb = subprocess.Popen([
        "Xvfb", ":1", "-screen", "0", f"{resolution}x{color_depth}"
    ])
    time.sleep(2)
    
    # Start VNC server
    server_cmd = ["tigervncserver", ":1", "-geometry", resolution]
    viewer_cmd = ["tigervncviewer", "localhost:1"]
    
    subprocess.run(server_cmd)
    time.sleep(3)
    
    # Run benchmark operations
    start_time = time.time()
    
    for i in range(operations):
        # Display image
        subprocess.run([
            "DISPLAY=:1", "feh", "--fullscreen", "/tmp/test_image.png"
        ], shell=True)
        time.sleep(1)
        
        # Take screenshot to measure roundtrip
        subprocess.run([
            "DISPLAY=:1", "import", "-window", "root", f"/tmp/benchmark_{i}.png"
        ], shell=True)
        time.sleep(1)
        
        # Close image viewer
        subprocess.run([
            "DISPLAY=:1", "killall", "feh"
        ], shell=True)
        time.sleep(1)
    
    end_time = time.time()
    
    # Measure bandwidth used (rough estimate)
    netstat = subprocess.run(
        ["netstat", "-n"], capture_output=True, text=True
    ).stdout
    
    # Calculate and store metrics
    results["metrics"]["total_time"] = end_time - start_time
    results["metrics"]["operations_per_second"] = operations / (end_time - start_time)
    
    # Cleanup
    subprocess.run(["tigervncserver", "-kill", ":1"])
    xvfb.terminate()
    
    # Clean up temp files
    for i in range(operations):
        if os.path.exists(f"/tmp/benchmark_{i}.png"):
            os.remove(f"/tmp/benchmark_{i}.png")
    if os.path.exists("/tmp/test_image.png"):
        os.remove("/tmp/test_image.png")
    
    return results

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TigerVNC benchmark utility")
    parser.add_argument("--resolution", default="1024x768", help="Screen resolution")
    parser.add_argument("--color-depth", type=int, default=24, help="Color depth")
    parser.add_argument("--operations", type=int, default=5, help="Number of test operations")
    parser.add_argument("--output", help="Output file for results (JSON)")
    
    args = parser.parse_args()
    
    print(f"Running benchmark for TigerVNC...")
    results = run_benchmark(
        args.resolution, 
        args.color_depth, 
        args.operations
    )
    
    print(f"Results: {json.dumps(results, indent=2)}")
    
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"Results saved to {args.output}") 