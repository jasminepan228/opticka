classdef seditor < handle
	%SEDITOR edits values from a stimulus class passed to it
	%   Detailed explanation goes here
	
	properties
		handles
		fn
		stim
		cprop
		ckind
		otherstimuli
	end
	
	methods
		function obj = seditor(stimin)
			if exist('stimin','var')
				obj.stim = stimin;
			end
			obj.handles = struct();
			oldlook=javax.swing.UIManager.getLookAndFeel;
			newlook='javax.swing.plaf.metal.MetalLookAndFeel';
			if ismac || ispc
				javax.swing.UIManager.setLookAndFeel(newlook);
			end
			obj.buildgui;
			drawnow;
			if ismac || ispc
				javax.swing.UIManager.setLookAndFeel(oldlook);
			end
			if ~isempty(obj.stim)
				obj.fn = fieldnames(obj.stim);
				set(obj.handles.StimEditorPropertyList,'String',obj.fn);
			end
			obj.StimEditorPropertyList_Callback;
		end
		
		function buildgui(obj)
			% Creation of all uicontrols
			
			% --- FIGURE -------------------------------------
			obj.handles.figure1 = figure( ...
				'Tag', 'figure1', ...
				'Units', 'pixels', ...
				'Position', [727 663 285 161], ...
				'Name', 'seditor', ...
				'MenuBar', 'none', ...
				'NumberTitle', 'off', ...
				'Color', [0.9 0.9 0.9]);
			
			% --- PUSHBUTTONS -------------------------------------
			
			obj.handles.StimEditorOK = uicontrol( ...
				'Parent', obj.handles.figure1, ...
				'Tag', 'StimEditorOK', ...
				'Style', 'pushbutton', ...
				'Units', 'pixels', ...
				'Position', [105 5 70 25], ...
				'FontName', 'Helvetica', ...
				'FontSize', 10, ...
				'String', 'OK', ...
				'Callback', @obj.StimEditorOK_Callback);
			
			% --- EDIT TEXTS -------------------------------------
			obj.handles.StimEditorEdit = uicontrol( ...
				'Parent', obj.handles.figure1, ...
				'Tag', 'StimEditorEdit', ...
				'Style', 'edit', ...
				'Units', 'pixels', ...
				'Position', [15 72 251 44], ...
				'FontName', 'Helvetica', ...
				'FontSize', 14, ...
				'BackgroundColor', [1 1 1], ...
				'String', '0', ...
				'Callback', @obj.StimEditorEdit_Callback);
			
			obj.handles.StimEditorStimList = uicontrol( ...
				'Parent', obj.handles.figure1, ...
				'Tag', 'StimEditorEdit', ...
				'Style', 'edit', ...
				'Units', 'pixels', ...
				'Position', [15 45 251 20], ...
				'FontName', 'Helvetica', ...
				'FontSize', 10, ...
				'TooltipString', 'Put a list of other stimuli in the list to try to edit', ...
				'BackgroundColor', [0.97 0.97 0.97], ...
				'String', '', ...
				'Callback', @obj.StimEditorStimList_Callback);
			
			% --- POPUP MENU -------------------------------------
			obj.handles.StimEditorPropertyList = uicontrol( ...
				'Parent', obj.handles.figure1, ...
				'Tag', 'StimEditorPropertyList', ...
				'Style', 'popupmenu', ...
				'Units', 'pixels', ...
				'Position', [6 118 274 35], ...
				'FontName', 'Helvetica', ...
				'FontSize', 10, ...
				'BackgroundColor', [1 1 1], ...
				'String', '0', ...
				'Callback', @obj.StimEditorPropertyList_Callback);
			
			% --- EDIT TEXTS -------------------------------------
			obj.handles.StimEditorText = uicontrol( ...
				'Parent', obj.handles.figure1, ...
				'Tag', 'StimEditorText', ...
				'Style', 'text', ...
				'Units', 'pixels', ...
				'Position', [15 30 251 15], ...
				'FontName', 'Helvetica', ...
				'FontSize', 9, ...
				'BackgroundColor', [0.9 0.9 0.9], ...
				'String', 'Number');
			
		end
		
		%% ---------------------------------------------------------------------------
		function StimEditorOK_Callback(obj,hObject,evendata) %#ok<INUSD>
			close(obj.handles.figure1)
		end
		
		%% ---------------------------------------------------------------------------
		function StimEditorEdit_Callback(obj,hObject,evendata) %#ok<INUSD>
			s=get(hObject,'String');
			
			switch obj.ckind
				case 'number'
					s=str2num(s);
					obj.stim.(obj.cprop) = s;
					
				case 'logical'
					s=str2num(s);
					if s > 0
						s=true;
					else
						s=false;
					end
					obj.stim.(obj.cprop) = s;
					
				case 'string'
					obj.stim.(obj.cprop) = s;
			end
			
			if isappdata(0,'o') %check opticka is running
				o = getappdata(0,'o');
				if ~isempty(obj.otherstimuli) %check if other stimuli are tagged to edit too
					for i=1:length(obj.otherstimuli)
						if ~isempty(findprop(o.r.stimulus{obj.otherstimuli(i)},obj.cprop)) %check it has this porperty
							o.r.stimulus{obj.otherstimuli(i)}.(obj.cprop) = s;
						end
					end
				end
				o.modifyStimulus; %flush the opticka UI and do what's needed
			end
		end
		
		%% ---------------------------------------------------------------------------
		function StimEditorStimList_Callback(obj,hObject,evendata) %#ok<INUSD>
			obj.otherstimuli = str2num(get(hObject,'String'));
		end
		
		%% ---------------------------------------------------------------------------
		function StimEditorPropertyList_Callback(obj,hObject,evendata) %#ok<INUSD>
			v=get(obj.handles.StimEditorPropertyList,'Value');
			s=get(obj.handles.StimEditorPropertyList,'String');
			obj.cprop=s{v};
			editvalue = obj.stim.(obj.cprop);
			if isnumeric(editvalue)
				obj.ckind='number';
				editvalue = num2str(editvalue);
				set(obj.handles.StimEditorText,'String','Number')
			elseif islogical(editvalue)
				obj.ckind='logical';
				editvalue = num2str(editvalue);
				set(obj.handles.StimEditorText,'String','Logical')
			else
				obj.ckind = 'string';
				set(obj.handles.StimEditorText,'String','String')
			end
			set(obj.handles.StimEditorEdit,'String',editvalue);
		end
		
	end
	
end

