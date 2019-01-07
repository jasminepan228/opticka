# Opticka Vision Experiment Generator #

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.12293.svg)](https://doi.org/10.5281/zenodo.592253)  

Opticka is an object oriented framework with optional GUI for the [Psychophysics toolbox (PTB)](http://psychtoolbox.org/wikka.php?wakka=HomePage), allowing randomised interleaved presentation of complex visual stimuli. It is designed to work on macOS, Linux, or Windows and interfaces via strobed words (using either a [Display++](https://www.crsltd.com/tools-for-vision-science/calibrated-displays/displaypp-lcd-monitor/), [DataPixx/ViewPixx](http://vpixx.com/products/tools-for-vision-sciences/) or a [LabJack](https://labjack.com/)) and ethernet for recording neurophysiological and behavioural data. Behavioural control uses the Eyelink eye tracker and a full behavioural repertoire is available by using a [Finite State-Machine](http://iandol.github.io/OptickaDocs/classstate_machine.html#details) controller. Opticka uses the TCP interface to the Eyelink affording much better control, reliability and data recording over using analog voltages alone. The various base classes can be used without the need to run the GUI (see [optickatest.m](http://iandol.github.io/OptickaDocs/optickatest.html) for an example), and plug-n-play stimuli provide a unified interface (setup, animate, draw, update, reset) to integrate into existing/other PTB routines. The various object methods take care of all the background geometry and normalization, meaning stimuli are much easier to use than “raw” PTB. Analysis routines are also present for taking the raw Plexon files (.PL2 or .PLX), Eyelink files (.EDF) and behavioural responses and parsing them into a consistent structure, interfacing directly with [Fieldtrip](http://fieldtrip.fcdonders.nl/start) for further spike, LFP, and spike-LFP analysis. The data structures allow the use of Jonathan Victor's [STA toolkit](http://www.ncbi.nlm.nih.gov/pmc/articles/PMC2818590/), and [nStat toolbox](http://www.neurostat.mit.edu/nstat/) (a pp-GLM modelling approach to analysing neural data). Opticka affords much better graphics control and is far more modular than [MonkeyLogic](http://www.brown.edu/Research/monkeylogic/).  

![Opticka Screenshot](https://github.com/iandol/opticka/raw/gh-pages/images/opticka.png)  

## Example hardware setup

![Example hardware setup to run Opticka](http://i62.tinypic.com/fxqq12.png)

We have also recently got Opticka working well via the [Display++ developed by CRS](https://www.crsltd.com/tools-for-vision-science/calibrated-displays/displaypp-lcd-monitor/). This means we should now support both the VPixx and CRS display replacements for vision research, affording great bit depth display output and using their built-in I/O for more robust experimental control.

# Quick Documentation
`optickatest.m` is a self-documenting minimal toy example showing a mini method of constants (MOC) experiment with 10 different stimuli. Read the Matlab-generated documentation for `optickatest.m` here: [optickatest.m Report](http://iandol.github.io/OptickaDocs/optickatest.html).
There is also auto-generated class documentation here: [Opticka Class Docs](http://iandol.github.io/OptickaDocs/inherits.html), however this is only as good as the comments in the code, which as always could be improved...  

# Install Instructions
Opticka prefers the latest Psychophysics Toolbox (V3.0.14+) and at least Matlab 2017a (it uses object-oriented property validation introduced in that version). It has been tested and is mostly used on 64bit Ubuntu 18.04 & macOS 10.14.x with Matlab 2018b. You can simply download the .ZIP from Github, and add the contents/subdirectories to Matlab path. Or if you have git installed, clone this Github repo and add to Matlab path.

Opticka currently works on Linux, macOS and Windows, though the LabJack interface currently only works under Linux and macOS (Labjack uses a different interface on windows and *nix, but this is a minor interface issue and would be a quick fix). Linux is by far the preferred OS according the PTB developer Mario Kleiner, and recieves the majority of development work, therefore it is strongly advised to use it for experiments.

## Features
* Values are always given in eye-relevant co-ordinates (degrees etc.) that are internally calculated based on screen geometry/distance
* No limit on the number of independent variables, and variables can be linked to multiple stimuli.
* A state machine logic can run behavioural tasks driven by for e.g. eye position or behavioural response. State machines can flexibly run tasks and chains of states define your experimental loop.
* Number of heterogeneous stimuli displayed simultaneously only limited by the GPU / computer power.
* Display lists are used, so one can easily change drawing order (i.e. what stimulus draws over other stimuli), by changing its order on the list.
* Object Oriented, allowing stimulus classes to be easily added and code to autodocument using DOxygen.
* The set of stimuli and variables can be saved into protocol files, to easily run successive protocols quickly.
* Fairly comprehensive control of the PTB interface to the drawing hardware, like blending mode, bit depth, windowing, verbosity.
* Colour is defined in floating point format, takes advantage of higher bit depths in newer graphics cards when available. The buffer can be defined from 8-32bits, use full alpha blending within that space and enable a >8bit output using pseudogrey bitstealing techniques.
* Sub-pixel precision (1/256th pixel) for movement and positioning.
* TTL output to data acquisition and other devices. Currently uses DataPixx or LabJack to interface to the Plexon Omniplex using strobed words.
* Can talk to other machines on the network during display using TCP/UDP (used to control a Plexon online display, so one can see PSTHs for each stimulus variable shown in real time).
* Each stimulus has its own relative X & Y position, and the screen centre can be arbitrarily moved via the GUI. This allows quick setup over particular parts of visual space, i.e. relative to a receptive field without needing to edit lots of other values.
* Can record stimuli to video files.
* Manages monitor calibration using ColorCalII from CRG or an i1Pro from ViewPixx. Calibration sets can be saved and loaded easily via the GUI.
* Gratings (all using procedural textures for high performance):
   * Per-frame update of properties for arbitrary numbers of grating patches.
   * Rectangular or circular aperture.
   * Cosine or hermite interpolation for filtering grating edges.
   * Square wave gratings, also using a procedural texture, i.e. very fast.
   * Gabors
* Coherent dot stimuli, coherence expressed from 0-1. Either square or round dots. Colours can be simple, random, random luminance or binary. Kill rates allow random replacement rates for dots. Circularly smoothed masked aperture option. Newsroom style dots with motion distributions etc.
* Bars, either solid colour or random noise texture. Bars can be animated, direction can be independent of their angle.
* Flashing/pulsing spots.
* Pictures/Images that can drift and rotate.
* Hand-mapping module - use mouse controlled dynamic bar / texture / colour to handmap receptive fields; includes logging of clicked position and later printout / storage of hand maps. These maps are in screen co-ordinates for quick subsequent stimulus placement.  

