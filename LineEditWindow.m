classdef LineEditWindow < handle
    % A base class for GUI tools that allow editing of linear data.
    %
    % Provides two pairs of charts, one pair are to display the entire
    % length of data, the other pair show a zoomed in section. An area of
    % the window is reserved for child defined buttons. The logic for
    % zooming in on data is provided by the MultiZoomer class.
    %
    % Child classes has access to a number of methods to cleanly access
    % functionality.

    properties (Access = private)
        figPosScaler % a 1 x 4 array used for placement in figure.

        buttons = struct(); % handles to uicontrols: built by addCommand
        keys = struct(); % one to one mapping with buttons: built by addCommand
        menus = struct();

        statusBar  % a text UI Control accessed with updateDisplay()

        % A modal window that is popped up when the user must wait for an
        % operation to complete.
        waitBarWindow

    end

    properties (Access = protected)
        figureHnd % the 1 figure used.
        charts = struct() % A structure containing the charts in figure.
        zoomer % The multiZoomer object used in this figure.
    end

    methods (Access = protected)

        function o = LineEditWindow()
            % Constructor creates the figure and places charts.
            %
            %  The figure is sized to fill most of the screen.  It creates
            %  and positions the charts along the top of the window and down
            %  the left hand side.  These charts all have their line hold
            %  states turned on, so that multiple lines can be added.

            % Given that MATLAB doesn't support creating maximised windows,
            % we just make it big, but leave a little space at the bottom
            % for the Windows menu bar.
            o.figureHnd = figure( ...
                'units', 'normalized', ...
                'OuterPosition', [0, 0.05, 1, 0.95], ...
                'ToolBar', 'none', ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none');

            % To aid in placement of charts and controls, set up a 25 x 25
            % gridline for the figure.
            o.figureHnd.Units = 'pixels';
            pos = o.figureHnd.Position;
            xs = pos(3)/25; % width
            ys = pos(4)/25; % height
            o.figPosScaler = [xs, ys, xs, ys];

            % Create the 4 charts, butting the full plots together and the
            % zoom plots together
            %TEMP!!! naming sapflow tool specific.
            o.charts.dtFull = o.makeChart([1, 22.25, 23, 1.75]);
            o.charts.kFull =  o.makeChart([1, 20, 23, 1.75]);
            o.charts.dtZoom = o.makeChart([1, 10.25, 17, 8.75]);
            o.charts.kZoom =  o.makeChart([1, 1, 17, 8.75]);
            % don't label the top plots' X axis
            o.charts.dtFull.XTickLabel = [];
            o.charts.dtZoom.XTickLabel = [];

            o.statusBar = uicontrol( ...
                'Parent', o.figureHnd, ...
                'Style', 'edit', 'String', '',...
                'Position', o.figPosScaler .* [1 * 1.75 + 17.5, 1, 1.5+2*1.75, 0.8], ...
                'Enable', 'Off' ...
            );


            % Install an object to handle panning and zooming of the charts.
            s.figure = o.figureHnd;
            s.fullCharts = {o.charts.dtFull, o.charts.kFull};
            s.zoomCharts = {o.charts.dtZoom, o.charts.kZoom};
            o.zoomer = MultiZoomer(s);

            % The second zoomed charts is only used for viewing not editing,
            % so treat all mouse clicks in it as pan/zoom instructions.
            o.zoomer.handleMouseInput(2);

            %
            % All keypresses are handled through this callback.
            o.figureHnd.KeyPressFcn = @o.handleKeypress;
        end


        function plotHandle = createEmptyLine(o, chartName, style)
            % Generate a plot for later population
            %
            % The plot is attached to chartName and will sport the specified
            % style.
            plotHandle = plot(o.charts.(chartName), 0, 0, style, 'Visible', 'Off', 'PickableParts', 'none');
        end


        function addCommand(o, name, menu, text, key, toolTip, col, row, callback)
            % Creates a button and corresponding keyboard shortcut
            %
            % The button is located in the figure's button region.
            %
            % name: used to refer to button from within code
            % text: to display on button
            % key: associated keyboard shortcut (the same callback is
            % called by both
            % toolTip: displayed text when cursor dwells over button
            % col, row: position of button in region
            % callback: is invoked on button click or keypress.
            %
            % By default the command is disabled - see enableCommands()
            %

            if row && col
                o.buttons.(name) = uicontrol( ...
                    'Parent', o.figureHnd, ...
                    'Style', 'pushbutton', 'String', text,...
                    'Callback', callback, ...
                    'Position', o.figPosScaler .* [col * 1.75 + 17.5, row + 1, 1.5, 0.8], ...
                    'TooltipString', sprintf('%s ("%s")',toolTip, key), ...
                    'KeyPressFcn', @o.handleKeypress, ...
                    'Enable', 'Off' ...
                );
            end

            if isa(menu, 'matlab.ui.container.Menu')
                o.menus.(name) = uimenu( ...
                    menu, ...
                    'Label', text, ...
                    'Callback', callback, ...
                    'Enable', 'Off' ...
                );
                if strfind(key, 'control-')
                    o.menus.(name).Accelerator = key(end);
                end
            end

            o.keys.(name) = struct( ...
                'Key', key, 'Enable', 0, 'Callback', callback ...
            );
        end


        function disableCommands(o, names)
            % Greys out specified buttons
            %
            % Where names is a 1 x N cell array of strings corresponding
            % with the controls to turn off.  These are the names passed to
            % addCommand().
            %
            % If names is empty then all commands are disabled.
            %
            % see also: enableCommands

            %TEMP!!! naming inconsistent with addCommand()
            o.setCommandState(names, 'Off');
        end


        function enableCommands(o, names)
            % The counterpart to disableCommands
            o.setCommandState(names, 'On')
        end

        function renameCommand(o, name, string)
            if isfield(o.buttons, name)
                o.buttons.(name).String = string;
            end
            if isfield(o.menus, name)
                o.menus.(name).Label = string;
            end
        end


        function reportStatus(o, format, varargin)
            % Updates the status bar
            o.statusBar.String = sprintf(format, varargin{:});
            drawnow();
        end


        function disableChartsControl(o)
            for name = fieldnames(o.charts)'
                o.charts.(name{1}).PickableParts = 'none';
            end
        end


        function enableChartsControl(o)
            for name = fieldnames(o.charts)'
                o.charts.(name{1}).PickableParts = 'visible';
            end
        end

        function setWindowTitle(o, format, varargin)
            % Sets the text at the top of the window.  Accepts printf()
            % arguments.
            o.figureHnd.Name = sprintf(format, varargin{:});
        end

        function startWait(o, message)
            % Create a modal window while we execute a lengthy command.
            % This is the easy way of preventing user access to any of the
            % controls on the main figure.
            o.figureHnd.Pointer = 'watch';
            drawnow();
            o.waitBarWindow = waitbar(0, message, 'Name', message, 'WindowStyle', 'modal');
        end


        function updateWait(o, progress, format, varargin)
            message = sprintf(format, varargin{:});
            waitbar(progress, o.waitBarWindow, message);
        end


        function endWait(o)
            % Whatever lengthy task we started has finished so remove the
            % modal (blocking) waitbar window.
            o.figureHnd.Pointer = 'arrow';
            delete(o.waitBarWindow);

        end


    end

    methods (Access = private)

        function setCommandState(o, names, state)
            if isempty(names)
                % select all
                names = fieldnames(o.keys)';
            end
            for name = names
                nameV = name{1};
                o.keys.(nameV).Enable = state;
                if isfield(o.buttons, nameV)
                    o.buttons.(nameV).Enable = state;
                end
                if isfield(o.menus, nameV)
                    o.menus.(nameV).Enable = state;
                end
            end
        end

        function handleKeypress(o, ~, event)
            % Callback for any keypress event.
            %
            % Searches the keys structure for the corresponding key and, if
            % found, calls the corresponding function.
            key = sprintf('%s%s',sprintf('%s-', event.Modifier{:}), event.Key);
            for name = fieldnames(o.keys)'
                keyData = o.keys.(name{1});
                % If this is the key, and it's enabled ...
                if strcmp(keyData.Key, key)
                    if strcmp(keyData.Enable, 'On')
                        % ... execute the corresponding command.
                        keyData.Callback(0,0);
                    end
                    return;
                end
            end
            if strcmp(key, 'alt-alt')
            else
                fprintf('Unhandled key: "%s"\n', key);
            end
        end

        function a = makeChart(o, pos)
            % Helper function used by constructor.

            % Charts have a bounding box, grids and don't respond to mouse
            % click by default.
            a = axes( ...
                'Units', 'pixels', ...
                'Parent', o.figureHnd, ...
                'Position', pos .* o.figPosScaler, ...
                'PickableParts', 'none', ...
                'XGrid', 'on', 'YGrid', 'on', ...
                'Box', 'on' ...
            );
            hold(a, 'on');  % so we can add numerous lines
        end


    end
end


