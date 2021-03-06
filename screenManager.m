% ========================================================================
%> @brief screenManager Manages a Screen object
%> screenManager manages PTB screen settings for opticka. You can set many
%> properties of this class to control PTB screens, and use it to open and
%> close the screen based on those properties. It also manages movie
%> recording of the screen buffer and some basic drawing commands like grids,
%> spots and the hide flash trick from Mario.
% ========================================================================
classdef screenManager < optickaCore
	
	properties
		%> MBP 1440x900 is 33.2x20.6cm so approx 44px/cm, Flexscan is 32px/cm @1280 26px/cm @ 1024
		%> use calibrateSize.m to measure this value
		pixelsPerCm double = 44
		%> distance of subject from CRT -- rad2ang(2*(atan((0.5*1cm)/57.3cm))) equals 1deg
		distance double = 57.3
		%> hide the black flash as PTB tests its refresh timing, uses a gamma
		%> trick from Mario
		hideFlash logical = false
		%> windowed: when FALSE use fullscreen; set to TRUE and it is windowed 800x600pixels or you
		%> can add in a window width and height i.e. [800 600] to specify windowed size. Remember
		%> that windowed presentation should never be used for real experimental
		%> presentation due to poor timing...
		windowed = false
		%> change the debug parameters for poorer temporal fidelity but no sync testing etc.
		debug logical = false
		%> true = shows the info text and position grid during stimulus presentation
		visualDebug logical = false
		%> normally should be left at 1 (1 is added to this number so doublebuffering is enabled)
		doubleBuffer uint8 = 1
		%> bitDepth of framebuffer, '8bit' is best for old GPUs, but prefer
		%> 'FloatingPoint32BitIfPossible' for newer GPUS, and can pass 
		%> options to enable Display++ modes 'EnableBits++Bits++Output'
		%> 'EnableBits++Mono++Output' or 'EnableBits++Color++Output'
		bitDepth char = 'FloatingPoint32BitIfPossible'
		%> timestamping mode 1=beamposition,kernel fallback | 2=beamposition crossvalidate with kernel
		timestampingMode double = 1
		%> multisampling sent to the graphics card, try values 0[disabled], 4, 8
		%> and 16 -- useful for textures to minimise aliasing, but this
		%> does provide extra work for the GPU
		antiAlias double = 0
		%> background RGBA of display during stimulus presentation
		backgroundColour double = [0.5 0.5 0.5 0]
		%> shunt screen center by X degrees
		screenXOffset double = 0
		%> shunt screen center by Y degrees
		screenYOffset double = 0
		%> the monitor to use, 0 is the main display
		screen double = []
		%> use OpenGL blending mode
		blend logical = false
		%> GL_ONE %src mode
		srcMode char = 'GL_SRC_ALPHA'
		%> GL_ONE % dst mode
		dstMode char = 'GL_ONE_MINUS_SRC_ALPHA'
		%> show a white square in the top-left corner to trigger a
		%> photodiode attached to screen. This is only displayed when the
		%> stimulus is shown, not during the blank and can therefore be used
		%> for timing validation
		photoDiode logical = false
		%> gamma correction info saved as a calibrateLuminance object
		gammaTable calibrateLuminance
		%> settings for movie output
		movieSettings = []
		%> useful screen info and initial gamma tables and the like
		screenVals struct
		%> verbosity
		verbose = false
		%> level of PTB verbosity, set to 10 for full PTB logging
		verbosityLevel double = 4
		%> Use retina resolution natively
		useRetina logical = false
		%> Screen To Head Mapping, a Nx3 vector: Screen('Preference', 'ScreenToHead', screen, head, crtc);
		%> Each N should be a different display
		screenToHead = []
		%> framerate for Display++ (120Hz or 100Hz, empty leaves as is)
		displayPPRefresh double = []
	end
	
	properties (Hidden = true)
		%> for some development macOS machines we have to disable sync tests,
		%> but we hide this as we should remember this is for development
		%> ONLY!
		disableSyncTests logical = false
	end
	
	properties (SetAccess = private, GetAccess = public, Dependent = true)
		%> dependent pixels per degree property calculated from distance and pixelsPerCm
		ppd
	end
	
	properties (SetAccess = private, GetAccess = public)
		%> do we have a working PTB, if not go into a silent mode
		isPTB logical = false
		%> is a PTB currently open?
		isOpen logical = false
		%> did we ask for a bitsPlusPlus mode?
		isPlusPlus logical = false
		%> the handle returned by opening a PTB window
		win
		%> the window rectangle
		winRect
		%> computed X center
		xCenter double = 0
		%> computed Y center
		yCenter double = 0
		%> set automatically on construction
		maxScreen
	end
	
	properties (SetAccess = private, GetAccess = private)
		%> linux font name;
		linuxFontName char = '-adobe-helvetica-bold-o-normal--11-80-100-100-p-60-iso8859-1'
		%> properties allowed to be modified during construction
		allowedProperties char = 'displayPPRefresh|screenToHead|gammaTable|useRetina|bitDepth|pixelsPerCm|distance|screen|windowed|backgroundColour|screenXOffset|screenYOffset|blend|srcMode|dstMode|antiAlias|debug|photoDiode|verbose|hideFlash'
		%> possible bitDepths
		bitDepths cell = {'FloatingPoint32BitIfPossible'; 'FloatingPoint32Bit'; 'FixedPoint16Bit'; 'FloatingPoint16Bit'; '8bit'; 'EnableBits++Bits++Output'; 'EnableBits++Mono++Output'; 'EnableBits++Color++Output'; 'EnablePseudoGrayOutput'; 'EnableNative10BitFramebuffer' }
		%> possible blend modes
		blendModes cell = {'GL_ZERO'; 'GL_ONE'; 'GL_DST_COLOR'; 'GL_ONE_MINUS_DST_COLOR'; 'GL_SRC_ALPHA'; 'GL_ONE_MINUS_SRC_ALPHA'; 'GL_DST_ALPHA'; 'GL_ONE_MINUS_DST_ALPHA'; 'GL_SRC_ALPHA_SATURATE' }
		%> the photoDiode rectangle in pixel values
		photoDiodeRect(1,4) double = [0, 0, 60, 60]
		%> the values computed to draw the 1deg dotted grid in visualDebug mode
		grid
		%> the movie pointer
		moviePtr = []
		%> movie mat structure
		movieMat = []
		%screen flash logic
		flashInterval = 20
		flashTick = 0
		flashOn = 1
		% timed spot logic
		timedSpotTime = 0
		timedSpotTick = 0
		timedSpotNextTick = 0
		ppd_
	end
	
	methods
		% ===================================================================
		%> @brief Class constructor
		%>
		%> screenManager constructor
		%>
		%> @param varargin can be simple name value pairs, a structure or cell array
		%> @return instance of the class.
		% ===================================================================
		function obj = screenManager(varargin)
			if nargin == 0; varargin.name = ''; end
			obj=obj@optickaCore(varargin); %superclass constructor
			if nargin>0
				obj.parseArgs(varargin,obj.allowedProperties);
			end
			try
				AssertOpenGL
				obj.isPTB = true;
				if strcmpi(computer,'MACI64')
					obj.salutation('64bit OS X PTB currently supported!')
				else
					obj.salutation('PTB currently supported!')
				end
			catch %#ok<*CTCH>
				obj.isPTB = false;
				obj.salutation('OpenGL support needed by PTB!')
			end
			prepareScreen(obj);
		end
		
		% ===================================================================
		%> @brief prepare the Screen values on the local machine
		%>
		%> @param obj object
		%> @return screenVals structure of screen values
		% ===================================================================
		function screenVals = prepareScreen(obj)
			if obj.isPTB == false
				obj.maxScreen = 0;
				obj.screen = 0;
				obj.screenVals.resetGamma = false;
				obj.screenVals.fps = 60;
				obj.screenVals.ifi = 1/60;
				obj.screenVals.width = 0;
				obj.screenVals.height = 0;
				obj.makeGrid;
				screenVals = obj.screenVals;
				return
			end
			obj.maxScreen=max(Screen('Screens'));
			
			%by default choose the (largest number) screen
			if isempty(obj.screen) || obj.screen > obj.maxScreen
				obj.screen = obj.maxScreen;
			end
			
			obj.screenVals = struct();
			
			
			%get the gammatable and dac information
			[obj.screenVals.gammaTable,obj.screenVals.dacBits,obj.screenVals.lutSize]=Screen('ReadNormalizedGammaTable', obj.screen);
			obj.screenVals.originalGammaTable = obj.screenVals.gammaTable;
			
			%get screen dimensions
			setScreenSize(obj);
			
			obj.screenVals.resetGamma = false;
			
			%this is just a rough initial setting, it will be recalculated when we
			%open the screen before showing stimuli.
			obj.screenVals.fps=Screen('FrameRate',obj.screen);
			if obj.screenVals.fps == 0
				obj.screenVals.fps = 60;
			end
			obj.screenVals.ifi=1/obj.screenVals.fps;
			
			% initialise our movie settings
			obj.movieSettings.loop = Inf;
			obj.movieSettings.record = false;
			obj.movieSettings.size = [600 600];
			obj.movieSettings.fps = 30;
			obj.movieSettings.quality = 0.7;
			obj.movieSettings.keyframe = 5;
			obj.movieSettings.nFrames = obj.screenVals.fps * 2;
			obj.movieSettings.type = 1;
			obj.movieSettings.codec = 'x264enc'; %space is important for 'rle '
			
			%Screen('Preference', 'TextRenderer', 0); %fast text renderer
			
			if obj.debug == true %we yoke these together but they can then be overridden
				obj.visualDebug = true;
			end
			if ismac
				obj.disableSyncTests = true;
			end
			
			obj.ppd; %generate our dependent propertie and caches it to ppd_ for speed
			obj.makeGrid; %our visualDebug size grid
			
			obj.screenVals.white = WhiteIndex(obj.screen);
			obj.screenVals.black = BlackIndex(obj.screen);
			obj.screenVals.gray = GrayIndex(obj.screen);
			
			if IsLinux
				d=Screen('ConfigureDisplay','Scanout',obj.screen,0);
				obj.screenVals.name = d.name;
				obj.screenVals.widthMM = d.displayWidthMM;
				obj.screenVals.heightMM = d.displayHeightMM;
				obj.screenVals.display = d;
			end
			
			screenVals = obj.screenVals;
			
		end
		
		% ===================================================================
		%> @brief open a screen with object defined settings
		%>
		%> @param debug, whether we show debug status, called from runExperiment
		%> @param tL timeLog object to add timing info on screen construction
		%> @return screenVals structure of basic info from the opened screen
		% ===================================================================
		function screenVals = open(obj,debug,tL,forceScreen)
			if obj.isPTB == false
				warning('No PTB found!')
				screenVals = obj.screenVals;
				return;
			end
			if ~exist('debug','var') || isempty(debug)
				debug = obj.debug;
			end
			if ~exist('tL','var') || isempty(tL)
				tL = struct;
			end
			if ~exist('forceScreen','var')
				forceScreen = [];
			end
			
			try
				PsychDefaultSetup(2);
				obj.screenVals.resetGamma = false;
				
				obj.hideScreenFlash();
				
				if ~isempty(obj.screenToHead) && isnumeric(obj.screenToHead)
					for i = 1:size(obj.screenToHead,1)
						sth = obj.screenToHead(i,:);
						if lengtht(stc) == 3
							fprintf('\n---> screenManager: Custom Screen to Head: %i %i %i\n',sth(1), sth(2), sth(3));
							Screen('Preference', 'ScreenToHead', sth(1), sth(2), sth(3));
						end
					end
				end
				
				%1=beamposition,kernel fallback | 2=beamposition crossvalidate with kernel
				%Screen('Preference', 'VBLTimestampingMode', obj.timestampingMode);
				
				if ~islogical(obj.windowed) && isnumeric(obj.windowed) %force debug for windowed stimuli!
					debug = true;
				end
				
				if debug == true || (length(obj.windowed)==1 && obj.windowed ~= 0)
					fprintf('\n---> screenManager: Skipping Sync Tests etc. - ONLY FOR DEVELOPMENT!\n');
					Screen('Preference', 'SkipSyncTests', 2);
					Screen('Preference', 'VisualDebugLevel', 0);
					Screen('Preference', 'Verbosity', 2);
					Screen('Preference', 'SuppressAllWarnings', 0);
				else
					if obj.disableSyncTests
						fprintf('\n---> screenManager: Sync Tests OVERRIDDEN, do not use during experiments!\n');
						Screen('Preference', 'SkipSyncTests', 2);
					else
						fprintf('\n---> screenManager: Normal Screen Preferences used.\n');
						Screen('Preference', 'SkipSyncTests', 0);
					end
					Screen('Preference', 'VisualDebugLevel', 3);
					Screen('Preference', 'Verbosity', obj.verbosityLevel); %errors and warnings
					Screen('Preference', 'SuppressAllWarnings', 0);
				end
				
				tL.screenLog.preOpenWindow=GetSecs;
				
				PsychImaging('PrepareConfiguration');
				PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
				PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange'); %we always want 0-1 colour range!
				fprintf('---> screenManager: Probing for a Display++...\n');
				bitsCheckOpen(obj);
				if obj.isPlusPlus; fprintf('---> screenManager: Found Display++...\n'); else; fprintf('no Display++...\n'); end
				if regexpi(obj.bitDepth, '^EnableBits')
					if obj.isPlusPlus
						fprintf('\t-> Display++ mode: %s\n', obj.bitDepth);
						PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'ClampOnly');
						if regexp(obj.bitDepth, 'Color')
							PsychImaging('AddTask', 'General', obj.bitDepth, 2);
						else
							PsychImaging('AddTask', 'General', obj.bitDepth);
						end
					else
						fprintf('---> screenManager: No Display++ found, revert to FloatingPoint32Bit mode.\n');
						PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
						obj.isPlusPlus = false;
					end
				else
					fprintf('\n---> screenManager: Bit Depth mode set to: %s\n', obj.bitDepth);
					PsychImaging('AddTask', 'General', obj.bitDepth);
					obj.isPlusPlus = false;
				end
				if obj.useRetina == true
					fprintf('---> screenManager: Retina mode enabled\n');
					PsychImaging('AddTask', 'General', 'UseRetinaResolution');
				end
				
				try %#ok<*TRYNC>
					if obj.isPlusPlus && ~isempty(obj.displayPPRefresh) && IsLinux
						outputID = 0;
						fprintf('\n---> screenManager: Set Display++ to %iHz\n',obj.displayPPRefresh);
						Screen('ConfigureDisplay','Scanout',obj.screen,outputID,[],[],obj.displayPPRefresh);
					end
				end
				
				if isempty(obj.windowed); obj.windowed = false; end
				thisScreen = obj.screen;
				if obj.windowed == false %fullscreen
					winSize = [];
				else %windowed
					if length(obj.windowed) == 2
						winSize = [0 0 obj.windowed(1) obj.windowed(2)];
					elseif length(obj.windowed) == 4
						winSize = obj.windowed;
					else
						winSize=[0 0 800 800];
					end
				end
				if ~isempty(forceScreen)
					thisScreen = forceScreen;
				end
				
				[obj.win, obj.winRect] = PsychImaging('OpenWindow', thisScreen, obj.backgroundColour, winSize, [], obj.doubleBuffer+1,[],obj.antiAlias);
				
				tL.screenLog.postOpenWindow=GetSecs;
				tL.screenLog.deltaOpenWindow=(tL.screenLog.postOpenWindow-tL.screenLog.preOpenWindow)*1000;
				
				try
					AssertGLSL;
				catch
					obj.close();
					error('GLSL Shading support is required for Opticka!');
				end
				
				if IsLinux
					d=Screen('ConfigureDisplay','Scanout',obj.screen,0);
					obj.screenVals.name = d.name;
					obj.screenVals.widthMM = d.displayWidthMM;
					obj.screenVals.heightMM = d.displayHeightMM;
					obj.screenVals.display = d;
				end
				
				obj.screenVals.win = obj.win; %make a copy
				obj.screenVals.winRect = obj.winRect; %make a copy
				
				Priority(MaxPriority(obj.win)); %bump our priority to maximum allowed
				
				obj.screenVals.ifi = Screen('GetFlipInterval', obj.win);
				obj.screenVals.fps=Screen('NominalFramerate', obj.win);
				%find our fps if not defined above
				if obj.screenVals.fps==0
					obj.screenVals.fps=round(1/obj.screenVals.ifi);
					if obj.screenVals.fps==0
						obj.screenVals.fps=60;
					end
				end
				if obj.windowed == false %fullscreen
					obj.screenVals.halfisi=obj.screenVals.ifi/2;
				else
					% windowed presentation doesn't handle the preferred method
					% of specifying lastvbl+halfisi properly so we set halfisi to 0 which
					% effectively makes flip occur ASAP.
					obj.screenVals.halfisi = 0;
				end
				
				%get screen dimensions -- check !!!!!
				setScreenSize(obj);
				
				if obj.hideFlash == true && isempty(obj.gammaTable)
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
					obj.screenVals.resetGamma = false;
				elseif ~isempty(obj.gammaTable) && (obj.gammaTable.choice > 0)
					choice = obj.gammaTable.choice;
					obj.screenVals.resetGamma = true;
					if size(obj.gammaTable.gammaTable,2) > 1
						if isprop(obj.gammaTable,'finalCLUT') && ~isempty(obj.gammaTable.finalCLUT)
							gTmp = obj.gammaTable.finalCLUT;
						else
							gTmp = [obj.gammaTable.gammaTable{choice,2:4}];
						end
					else
						gTmp = repmat(obj.gammaTable.gammaTable{choice,1},1,3);
					end
					Screen('LoadNormalizedGammaTable', obj.screen, gTmp);
					fprintf('\n---> screenManager: SET GAMMA CORRECTION using: %s\n', obj.gammaTable.modelFit{choice}.method);
					if isprop(obj.gammaTable,'correctColour') && obj.gammaTable.correctColour == true
						fprintf('---> screenManager: GAMMA CORRECTION used independent RGB Correction \n');
					end
				else
					%Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.gammaTable);
					%obj.screenVals.oldCLUT = LoadIdentityClut(obj.win);
					obj.screenVals.resetGamma = false;
				end
				
				% Enable alpha blending.
				if obj.blend==1
					[obj.screenVals.oldSrc,obj.screenVals.oldDst,obj.screenVals.oldMask]...
						= Screen('BlendFunction', obj.win, obj.srcMode, obj.dstMode);
					fprintf('\n---> screenManager: Previous OpenGL blending was %s | %s\n', obj.screenVals.oldSrc, obj.screenVals.oldDst);
					fprintf('---> screenManager: OpenGL blending now set to %s | %s\n', obj.srcMode, obj.dstMode);
				end
				
				Priority(0); %be lazy for a while and let other things get done
				
				if IsLinux
					%Screen('Preference', 'TextRenderer', 1);
					%Screen('Preference', 'DefaultFontName', 'DejaVu Sans');
				end
				
				obj.screenVals.white = WhiteIndex(obj.screen);
				obj.screenVals.black = BlackIndex(obj.screen);
				obj.screenVals.gray = GrayIndex(obj.screen);
				
				obj.isOpen = true;
				screenVals = obj.screenVals;
				
			catch ME
				obj.close();
				screenVals = obj.prepareScreen();
				rethrow(ME)
			end
			
		end
		
		% ===================================================================
		%> @brief Small demo
		%>
		%> @param
		%> @return
		% ===================================================================
		function demo(obj)
			if ~obj.isOpen
				stim = textureStimulus('speed',2,'xPosition',-6,'yPosition',0,'size',1);
				prepareScreen(obj);
				open(obj);
				obj.screenVals
				setup(stim, obj);
				flip(obj);
				for i = 1:600
					draw(stim);
					finishDrawing(obj);
					animate(stim);
					flip(obj);
				end
				WaitSecs(1);
				close(obj);
			end
		end
		
		% ===================================================================
		%> @brief Flip the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function vbl = flip(obj)
			vbl = Screen('Flip',obj.win);
		end
		
		% ===================================================================
		%> @brief check for display++, and keep open or close again
		%>
		%> @param port optional serial USB port
		%> @return keepOpen should we keep it open after check (default yes)
		% ===================================================================
		function connected = bitsCheckOpen(obj,port,keepOpen)
			connected = false;
			if ~exist('keepOpen','var') || isempty(keepOpen)
				keepOpen = true;
			end
			try
				if ~exist('port','var')
					ret = BitsPlusPlus('OpenBits#');
					if ret == 1; connected = true; end
					if ~keepOpen; BitsPlusPlus('Close'); end
				else
					ret = BitsPlusPlus('OpenBits#',port);
					if ret == 1; connected = true; end
					if ~keepOpen; BitsPlusPlus('Close'); end
				end
			end
			obj.isPlusPlus = connected;
		end
		
		% ===================================================================
		%> @brief Flip the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function bitsSwitchStatusScreen(obj)
			BitsPlusPlus('SwitchToStatusScreen');
		end
		
		% ===================================================================
		%> @brief force this object to use antother window
		%>
		%> @param
		%> @return
		% ===================================================================
		function forceWin(obj,win)
			obj.win = win;
			obj.isOpen = true;
			obj.isPTB = true;
			obj.screenVals.ifi = Screen('GetFlipInterval', obj.win);
			obj.screenVals.white = WhiteIndex(obj.win);
			obj.screenVals.black = BlackIndex(obj.win);
			obj.screenVals.gray = GrayIndex(obj.win);
			setScreenSize(obj);
			fprintf('---> screenManager slaved to external win: %i\n',win);
		end
		
		% ===================================================================
		%> @brief This is the trick Mario told us to "hide" the colour changes as PTB starts -- we could use backgroundcolour here to be even better
		%>
		%> @param
		%> @return
		% ===================================================================
		function hideScreenFlash(obj)
			% This is the trick Mario told us to "hide" the colour changes as PTB
			% intialises -- we could use backgroundcolour here to be even better
			if obj.hideFlash == true && all(obj.windowed == false)
				if isa(obj.gammaTable,'calibrateLuminance') && (obj.gammaTable.choice > 0)
					obj.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', obj.screen, repmat(obj.gammaTable.gammaTable{obj.gammaTable.choice}(128,:), 256, 3));
					obj.screenVals.resetGamma = true;
				else
					table = repmat(obj.backgroundColour(:,1:3), 256, 1);
					obj.screenVals.oldGamma = Screen('LoadNormalizedGammaTable', obj.screen, table);
					obj.screenVals.resetGamma = true;
				end
			end
		end
		
		% ===================================================================
		%> @brief close the screen when finished or on error
		%>
		%> @param
		%> @return
		% ===================================================================
		function close(obj)
			if obj.isPTB == true
				if isfield(obj.screenVals,'originalGammaTable') && ~isempty(obj.screenVals.originalGammaTable)
					Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.originalGammaTable);
					fprintf('\n---> screenManager: RESET GAMMA TABLES\n');
				end
				wk = Screen(obj.win, 'WindowKind');
				if obj.blend == true & wk ~= 0
					%this needs to be done to not trigger a Linux+Polaris bug
					%matlab bug
					Screen('BlendFunction', obj.win, 'GL_ONE','GL_ZERO');
					fprintf('---> screenManager: RESET OPENGL BLEND MODE to GL_ONE & GL_ZERO\n');
				end
				if obj.isPlusPlus
					BitsPlusPlus('Close');
				end
				obj.finaliseMovie(); obj.moviePtr = [];
				Screen('Close');
				obj.win=[]; 
				if isfield(obj.screenVals,'win');rmfield(obj.screenVals,'win');end
				obj.isOpen = false;
				obj.isPlusPlus = false;
				Priority(0);
				ListenChar(0);
				ShowCursor;
				sca;
			end
		end
		
		
		% ===================================================================
		%> @brief reset the gamma table
		%>
		%> @param
		%> @return
		% ===================================================================
		function resetScreenGamma(obj)
			if obj.hideFlash == true || obj.windowed(1) ~= 1 || (~isempty(obj.screenVals) && obj.screenVals.resetGamma == true && ~isempty(obj.screenVals.originalGammaTable))
				fprintf('\n---> screenManager: RESET GAMMA TABLES\n');
				Screen('LoadNormalizedGammaTable', obj.screen, obj.screenVals.originalGammaTable);
			end
		end
		
		% ===================================================================
		%> @brief Set method for bitDepth
		%>
		%> @param
		% ===================================================================
		function set.bitDepth(obj,value)
			check = strcmpi(value,obj.bitDepths);
			if any(check)
				obj.bitDepth = obj.bitDepths{check};
			else
				warning('Wrong Value given, select from list below')
				disp(obj.bitDepths)
			end
		end
		
		% ===================================================================
		%> @brief Set method for distance
		%>
		%> @param
		% ===================================================================
		function set.distance(obj,value)
			if ~(value > 0)
				value = 57.3;
			end
			obj.distance = value;
			obj.makeGrid();
		end
		
		% ===================================================================
		%> @brief Set method for pixelsPerCm
		%>
		%> @param
		% ===================================================================
		function set.pixelsPerCm(obj,value)
			if ~(value > 0)
				value = 44;
			end
			obj.pixelsPerCm = value;
			obj.makeGrid();
		end
		
		% ===================================================================
		%> @brief Get method for ppd (a dependent property)
		%>
		%> @param
		% ===================================================================
		function ppd = get.ppd(obj)
			if obj.useRetina %note pixelsPerCm is normally recorded using non-retina mode so we fix that here if we are now in retina mode
				ppd = ( (obj.pixelsPerCm*2) * (obj.distance / 57.3) ); %set the pixels per degree
			else
				ppd = ( obj.pixelsPerCm * (obj.distance / 57.3) ); %set the pixels per degree
			end
			obj.ppd_ = ppd; %cache value for speed!!!
		end
		
		% ===================================================================
		%> @brief Set method for windowed
		%>
		%> @param
		% ===================================================================
		function set.windowed(obj,value)
			if length(value) == 2 && isnumeric(value)
				obj.windowed = [0 0 value];
			elseif length(value) == 4 && isnumeric(value)
				obj.windowed = value;
			elseif islogical(value)
				obj.windowed = value;
			elseif value == 1
				obj.windowed = true;
			elseif value == 0
				obj.windowed = false;
			else
				obj.windowed = false;
			end
		end
		
		% ===================================================================
		%> @brief Set method for pixelsPerCm
		%>
		%> @param
		% ===================================================================
		function set.screenXOffset(obj,value)
			obj.screenXOffset = value;
			obj.updateCenter();
		end
		
		% ===================================================================
		%> @brief Set method for pixelsPerCm
		%>
		%> @param
		% ===================================================================
		function set.screenYOffset(obj,value)
			obj.screenYOffset = value;
			obj.updateCenter();
		end
		
		% ===================================================================
		%> @brief Set method for verbosityLevel
		%>
		%> @param
		% ===================================================================
		function set.verbosityLevel(obj,value)
			obj.verbosityLevel = value;
			Screen('Preference', 'Verbosity', obj.verbosityLevel); %errors and warnings
		end
		
		% ===================================================================
		%> @brief Screen('DrawingFinished')
		%>
		%> @param
		% ===================================================================
		function finishDrawing(obj)
			Screen('DrawingFinished', obj.win);
		end
		
		% ===================================================================
		%> @brief Test if window is actully open
		%>
		%> @param
		% ===================================================================
		function testWindowOpen(obj)
			if obj.isOpen
				wk = Screen(obj.win, 'WindowKind');
				if wk == 0
					warning(['===>>> ' obj.fullName ' PTB Window is actually INVALID!']);
					obj.isOpen = 0;
					obj.win = [];
				else
					fprintf('===>>> %s VALID WindowKind = %i\n',obj.fullName,wk);
				end
			end
		end
		
		% ===================================================================
		%> @brief Flash the screen until keypress
		%>
		%> @param
		% ===================================================================
		function flashScreen(obj,interval)
			if obj.isOpen
				int = round(interval / obj.screenVals.ifi);
				KbReleaseWait;
				while ~KbCheck(-1)
					if mod(obj.flashTick,int) == 0
						obj.flashOn = not(obj.flashOn);
						obj.flashTick = 0;
					end
					if obj.flashOn == 0
						Screen('FillRect',obj.win,[0 0 0 1]);
					else
						Screen('FillRect',obj.win,[1 1 1 1]);
					end
					Screen('Flip',obj.win);
					obj.flashTick = obj.flashTick + 1;
				end
				drawBackground(obj);
				Screen('Flip',obj.win);
			end
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param size in degrees
		%> @param colour of spot
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @return
		% ===================================================================
		function drawSpot(obj,size,colour,x,y)
			if nargin < 5 || isempty(y); y = 0; end
			if nargin < 4 || isempty(x); x = 0; end
			if nargin < 3 || isempty(colour); colour = [1 1 1 1]; end
			if nargin < 2 || isempty(size); size = 1; end
			
			x = obj.xCenter + (x * obj.ppd_);
			y = obj.yCenter + (y * obj.ppd_);
			size = size/2 * obj.ppd_;
			
			Screen('gluDisk', obj.win, colour, x, y, size);
		end
		
		% ===================================================================
		%> @brief draw small cross
		%>
		%> @param size size in degrees
		%> @param colour of cross
		%> @param x position in degrees relative to screen center
		%> @param y position in degrees relative to screen center
		%> @param lineWidth of lines
		%> @return
		% ===================================================================
		function drawCross(obj,size,colour,x,y,lineWidth)
			% drawCross(obj,size,colour,x,y,lineWidth)
			if nargin < 6 || isempty(lineWidth); lineWidth = 2; end
			if nargin < 5 || isempty(y); y = 0; end
			if nargin < 4 || isempty(x); x = 0; end
			if nargin < 3 || isempty(colour)
				if mean(obj.backgroundColour(1:3)) <= 0.5
					colour = [1 1 1 1];
				elseif  mean(obj.backgroundColour(1:3)) > 0.5
					colour = [0 0 0 1];
				elseif length(colour) < 4
					colour = [0 0 0 1];
				end
			end
			if nargin < 2 || isempty(size); size = 0.5; end
			
			x = obj.xCenter + (x * obj.ppd_);
			y = obj.yCenter + (y * obj.ppd_);
			size = size/2 * obj.ppd_;
			
			Screen('DrawLines', obj.win, [-size size 0 0;0 0 -size size],...
				lineWidth, colour, [x y]);
		end
		
		% ===================================================================
		%> @brief draw timed small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawTimedSpot(obj,size,colour,time,reset)
			% drawTimedSpot(obj,size,colour,time,reset)
			if nargin < 5; reset = false; end
			if nargin < 4; time = 0.2; end
			if nargin < 3; colour = [1 1 1 1]; end
			if nargin < 2; size = 1; end
			if reset == true
				if length(time) == 2
					obj.timedSpotTime = randi(time*1000)/1000;
				else
					obj.timedSpotTime = time;
				end
				obj.timedSpotNextTick = round(obj.timedSpotTime / obj.screenVals.ifi);
				obj.timedSpotTick = 1;
				return
			end
			if obj.timedSpotTick <= obj.timedSpotNextTick
				size = size/2 * obj.ppd_;
				Screen('gluDisk',obj.win,colour,obj.xCenter,obj.yCenter,size);
			end
			obj.timedSpotTick = obj.timedSpotTick + 1;
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawGreenSpot(obj,size)
			% drawGreenSpot(obj,size)
			if ~exist('size','var')
				size = 1;
			end
			size = size/2 * obj.ppd_;
			Screen('gluDisk',obj.win,[0 1 0 1],obj.xCenter,obj.yCenter,size);
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawRedSpot(obj,size)
			% drawRedSpot(obj,size)
			if ~exist('size','var')
				size = 1;
			end
			size = size/2 * obj.ppd_;
			Screen('gluDisk',obj.win,[1 0 0 1],obj.xCenter,obj.yCenter,size);
		end
		
		% ===================================================================
		%> @brief draw text and flip immediately
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawTextNow(obj,text)
			% drawTextNow(obj,text)
			if ~exist('text','var');return;end
			Screen('DrawText',obj.win,text,0,0,[1 1 1],[0.5 0.5 0.5]);
			flip(obj);
		end
		
		% ===================================================================
		%> @brief draw small spot centered on the screen
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawScreenCenter(obj)
			Screen('gluDisk',obj.win,[1 0 1 1],obj.xCenter,obj.yCenter,2);
		end
		
		% ===================================================================
		%> @brief draw a 5x5 1deg dot grid for visual debugging
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawGrid(obj)
			Screen('DrawDots',obj.win,obj.grid,1,[1 0 1 1],[obj.xCenter obj.yCenter],1);
		end
		
		% ===================================================================
		%> @brief draw a square in top-left of screen to trigger photodiode
		%>
		%> @param colour colour of square
		%> @return
		% ===================================================================
		function drawPhotoDiodeSquare(obj,colour)
			% drawPhotoDiodeSquare(obj,colour)
			Screen('FillRect',obj.win,colour,obj.photoDiodeRect);
		end
		
		% ===================================================================
		%> @brief conditionally draw a white square to trigger photodiode
		%>
		%> @param colour colour of square
		%> @return
		% ===================================================================
		function drawPhotoDiode(obj,colour)
			% drawPhotoDiode(obj,colour)
			if obj.photoDiode;Screen('FillRect',obj.win,colour,obj.photoDiodeRect);end
		end
		
		% ===================================================================
		%> @brief Draw the background colour
		%>
		%> @param
		%> @return
		% ===================================================================
		function drawBackground(obj)
			Screen('FillRect',obj.win,obj.backgroundColour,[]);
		end
		
		% ===================================================================
		%> @brief return mouse position in degrees
		%>
		%> @param
		% ===================================================================
		function [xPos, yPos] = mousePosition(obj, verbose)
			if ~exist('verbose','var') || isempty(verbose); verbose = obj.verbose; end
			if obj.isOpen
				[xPos,yPos] = GetMouse(obj.win);
			else
				[xPos,yPos] = GetMouse();
			end
			xPos = (xPos - obj.xCenter) / obj.ppd_;
			yPos = (yPos - obj.yCenter) / obj.ppd_;
			if verbose
				fprintf('--->>> MOUSE POSITION: \tX = %5.5g \t\tY = %5.5g\n',xPos,yPos);
			end
		end
		
		% ===================================================================
		%> @brief prepare the recording of stimulus frames
		%>
		%> @param
		%> @return
		% ===================================================================
		function prepareMovie(obj)
			% Set up the movie settings
			if obj.movieSettings.record == true
				obj.movieSettings.outsize=CenterRect([0 0 obj.movieSettings.size(1) obj.movieSettings.size(2)],obj.winRect);
				obj.movieSettings.loop=1;
				if ismac || isunix
					oldp = cd('~');
					homep = pwd;
					cd(oldp);
				else
					homep = 'c:';
				end
				if ~exist([homep filesep 'MatlabFiles' filesep 'Movie' filesep],'dir')
					mkdir([homep filesep 'MatlabFiles' filesep 'Movie' filesep])
				end
				obj.movieSettings.moviepath = [homep filesep 'MatlabFiles' filesep 'Movie' filesep];
				switch obj.movieSettings.type
					case 1
						if isempty(obj.movieSettings.codec)
							settings = sprintf(':CodecSettings= Profile=3 Keyframe=%g Videoquality=%g',...
								obj.movieSettings.keyframe, obj.movieSettings.quality);
						else
							settings = sprintf(':CodecType=%s Profile=3 Keyframe=%g Videoquality=%g',...
								obj.movieSettings.codec, obj.movieSettings.keyframe, obj.movieSettings.quality);
						end
						obj.movieSettings.movieFile = [obj.movieSettings.moviepath 'Movie' datestr(now,'dd-mm-yyyy-HH-MM-SS') '.mov'];
						obj.moviePtr = Screen('CreateMovie', obj.win,...
							obj.movieSettings.movieFile,...
							obj.movieSettings.size(1), obj.movieSettings.size(2),...
							obj.movieSettings.fps, settings);
						fprintf('\n---> screenManager: Movie [enc:%s] [rect:%s] will be saved to:\n\t%s\n',settings,...
							num2str(obj.movieSettings.outsize),obj.movieSettings.movieFile);
					case 2
						obj.movieMat = zeros(obj.movieSettings.size(2),obj.movieSettings.size(1),3,obj.movieSettings.nFrames);
				end
			end
		end
		
		% ===================================================================
		%> @brief add current frame to recorded stimulus movie
		%>
		%> @param
		%> @return
		% ===================================================================
		function addMovieFrame(obj)
			if obj.movieSettings.record == true
				if obj.movieSettings.loop <= obj.movieSettings.nFrames
					switch obj.movieSettings.type
						case 1
							Screen('AddFrameToMovie', obj.win, obj.movieSettings.outsize, 'frontBuffer', obj.moviePtr);
						case 2
							obj.movieMat(:,:,:,obj.movieSettings.loop)=Screen('GetImage', obj.win,...
								obj.movieSettings.outsize, 'frontBuffer', obj.movieSettings.quality, 3);
					end
					obj.movieSettings.loop=obj.movieSettings.loop+1;
				end
			end
		end
		
		% ===================================================================
		%> @brief finish stimulus recording
		%>
		%> @param
		%> @return
		% ===================================================================
		function finaliseMovie(obj,wasError)
			if obj.movieSettings.record == true
				switch obj.movieSettings.type
					case 1
						if ~isempty(obj.moviePtr)
							Screen('FinalizeMovie', obj.moviePtr);
							fprintf(['\n---> screenManager: movie saved to ' obj.movieSettings.movieFile '\n']);
						end
					case 2
% 						if wasError == true
% 							
% 						else
% 							save([obj.movieSettings.moviepath 'Movie' datestr(clock) '.mat'],'mimg');
% 						end
				end
			end
			obj.moviePtr = [];
			obj.movieMat = [];
		end
		
		% ===================================================================
		%> @brief play back the recorded stimulus
		%>
		%> @param
		%> @return
		% ===================================================================
		function playMovie(obj)
			if obj.movieSettings.record == true  && obj.movieSettings.type == 2 && exist('implay','file') && ~isempty(obj.movieSettings.movieFile)
				try %#ok<TRYNC>
					mimg = load(obj.movieSettings.movieFile);
					implay(mimg);
					clear mimg
				end
			end
		end
		
		% ===================================================================
		%> @brief Delete method
		%>
		% ===================================================================
		function delete(obj)
			if obj.isOpen
				obj.close();
				obj.salutation('DELETE method','Screen closed');
			end
		end	
	end
	
	%=======================================================================
	methods (Access = private) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief Sets screen size, taking retina mode into account
		%>
		% ===================================================================
		function setScreenSize(obj)
			%get screen dimensions
			if ~isempty(obj.win)
				swin = obj.win;
			else
				swin = obj.screen;
			end
			[obj.screenVals.width, obj.screenVals.height] = Screen('WindowSize',swin);
			obj.winRect = Screen('Rect',swin);
			updateCenter(obj);
		end
		% ===================================================================
		%> @brief Makes a 15x15 1deg dot grid for debug mode
		%> This is always updated on setting distance or pixelsPerCm
		% ===================================================================
		function makeGrid(obj)
			obj.grid = [];
			rnge = -15:15;
			for i=rnge
				obj.grid = horzcat(obj.grid, [rnge;ones(1,length(rnge))*i]);
			end
			obj.grid = obj.grid .* obj.ppd;
		end
		
		% ===================================================================
		%> @brief update our screen centre to use any offsets we've defined
		%>
		%> @param
		% ===================================================================
		function updateCenter(obj)
			if length(obj.winRect) == 4
				%get the center of our screen, along with user defined offsets
				[obj.xCenter, obj.yCenter] = RectCenter(obj.winRect);
				obj.xCenter = obj.xCenter + (obj.screenXOffset * obj.ppd_);
				obj.yCenter = obj.yCenter + (obj.screenYOffset * obj.ppd_);
			end
		end
		
	end
	
end

