# 5G Massive MIMO Dynamic System-Level Simulator

![MATLAB](https://img.shields.io/badge/MATLAB-R2023a%2B-blue.svg)
![QuaDRiGa](https://img.shields.io/badge/QuaDRiGa-v2.8.1-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

A high-fidelity, dynamic system-level simulation framework for 5G Massive MIMO networks. This simulator models dynamic User Equipment (UE) mobility across diverse urban environments (e.g., Parks, Office Buildings, Highways) while accurately simulating physical layer constraints, weather attenuation, traffic load interference, and channel state information (CSI) using the **QuaDRiGa** channel model.

## Key Features

* **Dynamic Mobility & Environment:** Uses Voronoi diagrams to generate heterogeneous multi-scenario environments. UEs move dynamically with environment-aware velocities (e.g., fast on highways, slow in parks).
* **Weather & Traffic Simulation:** Incorporates ITU-R based rain attenuation models and time-of-day traffic loads (Rush Hour, Night, etc.) affecting SINR and interference.
* **Smart Base Station Selection:** Implements a deterministic, path-aware heuristic algorithm that prevents ping-pong effects and accounts for cross-area propagation penalties (LOS/NLOS boundary crossing).
* **Comprehensive CSI Reporting:** Real-time extraction of RSRP, RSRQ, SINR, and CQI, strictly utilizing hardware-realistic dynamic ranges.

---

## Architecture: The Two-Step Cell Selection & Evaluation Model

To optimize simulation runtime without sacrificing physical accuracy, this simulator employs a decoupled architecture for Base Station (BS) association and Channel Evaluation:

### 1. Phase 1: Heuristic BS Selection (The Smart Algorithm)
Instead of naively associating UEs to the geographically closest BS (which ignores physical obstacles), the simulator runs a deterministic heuristic evaluation. It calculates the Free Space Path Loss (FSPL) and applies a **Cross-Area Propagation Penalty**. The logic weighs the endpoint environment scenarios (LOS/NLOS) of both the UE and the BS. If the signal path crosses obscured boundaries, a penalty (up to 15dB) is applied to reflect physical obstacles like buildings. This allows UEs to logically connect to a geographically further BS if it provides a clearer Line-of-Sight (LOS).

### 2. Phase 2: Physical Channel Evaluation (QuaDRiGa)
Once the Serving BS is decided, the engine passes the connection mapping to the QuaDRiGa core. QuaDRiGa performs a rigorous multi-path ray-tracing approximation based on the exact 3D coordinates and scenario layout to determine the final, accurate CSI metrics (RSRP, SINR). *Note: The heuristic penalty from Phase 1 is strictly for decision-making and does not double-penalize the physics-based QuaDRiGa evaluation.*

---

## Requirements

* **MATLAB** (R2021a or newer, R2023b recommended).
* **Required Toolboxes:** Communications Toolbox, Phased Array System Toolbox, Statistics and Machine Learning Toolbox.
* **QuaDRiGa Channel Model** (v2.8.1). Must be extracted and added to the MATLAB path prior to running the simulation.

---

## How to Run

1. Clone this repository:
```bash
git clone [https://github.com/Omri154/5G-Massive-MIMO-Simulator.git](https://github.com/Omri154/5G-Massive-MIMO-Simulator.git)
```

2. Open MATLAB and navigate to the project root directory.
3. Ensure the QuaDRiGa source folder is in your MATLAB path.
4. Run the main simulation script:
```matlab
MainSimulation
```

5. Check the `results/` folder for generated CSV logs and high-resolution spatial/temporal plots.

---

## Running Tests

The `tests/` directory contains validation scripts for core components. Run them to ensure environment integrity before executing large-scale simulations:

* `TestNetworkManagers.m`: Validates BS and UE generation.
* `TestWeatherAndTraffic.m`: Validates environmental impact logic over different times of day.
* `TestCSIReporter.m`: Validates the interface between the simulation and QuaDRiGa.
* `TestDynamicSimulation.m`: Generates visual trajectories and path-loss correlations.

---

## License

This project is licensed under the MIT License - see the LICENSE file for details. You are free to use, modify, and distribute this software, provided that you include the original copyright notice.

---

## Author & Citation

**Developed by Omri Israeli**

If you use this simulation framework in your academic research, university project, or industry R&D, please consider starring the repository and citing it using the provided `CITATION.cff` file, or using the following format:

> Israeli, O. (2026). *5G Massive MIMO Dynamic System-Level Simulator* [Source Code]. GitHub. https://github.com/Omri154/5G-Massive-MIMO-Simulator

For questions, feedback, or collaboration, feel free to connect with me on [LinkedIn](https://www.linkedin.com/in/omriisraeli/).


graph TD
    classDef core fill:#e1f5fe,stroke:#333,stroke-width:2px;
    classDef external fill:#fff3e0,stroke:#f57c00,stroke-width:2px,stroke-dasharray: 5 5;
    classDef data fill:#e8f5e9,stroke:#333,stroke-width:1px;
    
    Config[1. Config Module<br/>simulation_config.m] ::: data
    
    Main((MainSimulation.m<br/>Entry Point)) ::: core
    
    subgraph System Modules
        Env[2. Environment Module<br/>AreaGenerator] ::: data
        Mob[3. Mobility Module<br/>Trace-Based / Random Walk] ::: data
        Net[4. Network Module<br/>BS & UE Managers] ::: data
        Sim[5. Simulation Module<br/>Time, Transition & CSIReporter] ::: core
    end
    
    Quad[(QuaDRiGa 2.8.1<br/>Channel Engine)] ::: external
    Utils[8. Utils Module<br/>Geometry, Traffic, Weather] ::: data
    
    Out[6. Output Module<br/>ResultsManager] ::: data
    
    Config -->|Injects Parameters| Main
    Utils -.->|Helper Functions| Main
    Utils -.->|Helper Functions| Sim
    
    Main -->|Initializes| Env
    Main -->|Initializes| Net
    Main -->|Updates & Moves| Mob
    Main -->|Manages Loop| Sim
    
    Mob -->|Location Data| Sim
    Env -->|Voronoi & Scenarios| Sim
    Net -->|Antenna Arrays| Sim
    
    Sim <-->|Batch Processing| Quad
    Sim -->|CSI Metrics| Out
