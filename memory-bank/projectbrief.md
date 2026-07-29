# Project Brief: fUSI_analyses

## Overview
A refactored MATLAB-based analysis pipeline for **functional Ultrasound Imaging (fUSI)** data in rodents. This is a fresh rewrite of an existing codebase originally developed by Chaoyi (`/data08/fUSI/fUSI-Analysis`), reorganized for clarity, modularity, and reproducibility.

## Core Goal
Transform legacy, monolithic MATLAB scripts into a clean, well-structured, and modular analysis pipeline for fUSI neuroscience data.

## Experimental Context
fUSI measures brain hemodynamics via **Power Doppler Imaging (PDI)** — the primary data type throughout this codebase. Experiments involve rodents (rats/mice in headfixed setups) undergoing various behavioral paradigms:

- **Visual stimulation** — full-field visual gratings; validates fUSI spatial specificity
- **Shock / Fear conditioning** — electric foot shocks; measures aversive responses
- **Shock Observation (Emotion Contagion)** — one animal observes another receiving shocks; dyad paradigm
- **Self Shock (SS)** — animal receives shocks directly
- **Ultrasound Stimulation (USS)** — focused ultrasound neuromodulation

## Key Requirements
1. Modular, reusable MATLAB functions replacing monolithic scripts
2. Clear separation of: raw data → preprocessing → analysis → results
3. New analyses go into `03_ANALYSES/` organized by paradigm (e.g., `VISUAL/`, `SHOCK/`)
4. Utility and shared functions stored in `AnalysisFcn/` (legacy) and `UTILS/`
5. Atlas-based ROI analysis using the Allen Brain Atlas
6. Support for both Linux (`/data06/`, `/data03/`) and Windows (`\\vs03\...`) data paths

## Project Scope
- Source of truth for legacy code: `AnalysisFcn/` directory
- Target for new analyses: `03_ANALYSES/` directory
- Memory bank lives in: `memory-bank/`
