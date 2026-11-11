%% ============================================================
% STEP 3: SOLVE AND SIMULATE 5-CLASS LULC DDE
% MATLAB R2019a
%
% Model:
% dX(t)/dt = A*X(t) + B*X(t-tau)
%
% Historical period: 2017-2025
% Forecast period:   2026-2035
%
% ============================================================

clear;
clc;
close all;

%% ============================================================
% 1. DATA FOLDER
% ============================================================

dataFolder = fileparts(mfilename('fullpath'));

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 3: SOLVE AND SIMULATE LULC DDE\n');
fprintf('============================================================\n');

%% ============================================================
% 2. LOAD STEP 1 DATA
% ============================================================

step1File = fullfile(dataFolder, ...
    'LULC_DDE_Input_2017_2025.mat');

if ~exist(step1File,'file')
    error(['Step 1 file not found:\n%s\n\n' ...
           'Run Step 1 first.'],step1File);
end

load(step1File);

fprintf('\nStep 1 data loaded successfully.\n');

%% ============================================================
% 3. CHECK STEP 1 VARIABLES
% ============================================================

if ~exist('X','var')
    error('Variable X was not found in Step 1 MAT file.');
end

if ~exist('classPercent','var')
    error('Variable classPercent was not found in Step 1 MAT file.');
end

if ~exist('years','var')
    error('Variable years was not found in Step 1 MAT file.');
end

%% ============================================================
% 4. LOAD STEP 2 DDE MODEL
% ============================================================

step2File = fullfile(dataFolder, ...
    'LULC_DDE_Model_2017_2025.mat');

if ~exist(step2File,'file')
    error(['Step 2 model not found:\n%s\n\n' ...
           'Run Step 2 first.'],step2File);
end

load(step2File,'A','B','tau');

fprintf('Step 2 DDE model loaded successfully.\n');

%% ============================================================
% 5. CLASS NAMES
% ============================================================

classNames = {'Water', ...
              'Low Vegetation', ...
              'High Vegetation', ...
              'Built-up', ...
              'Bare Land'};

nClasses = 5;

%% ============================================================
% 6. DISPLAY MODEL
% ============================================================

fprintf('\n============================================================\n');
fprintf('MATRIX A\n');
fprintf('============================================================\n');

disp(A);

fprintf('\n============================================================\n');
fprintf('MATRIX B\n');
fprintf('============================================================\n');

disp(B);

fprintf('\nDelay = %.2f year\n',tau);

%% ============================================================
% 7. LAST OBSERVED STATE
% ============================================================

x2025 = X(end,:)';

fprintf('\n============================================================\n');
fprintf('OBSERVED 2025 LULC\n');
fprintf('============================================================\n');

for j = 1:nClasses

    fprintf('%-20s %.6f  (%.4f%%)\n', ...
        classNames{j}, ...
        x2025(j), ...
        x2025(j)*100);

end

fprintf('Total                 %.6f\n',sum(x2025));

%% ============================================================
% 8. HISTORY FUNCTION
% ============================================================

history = x2025;

%% ============================================================
% 9. DDE FUNCTION
% ============================================================

ddeFunction = @(t,x,Z) ...
    A*x + B*Z(:,1);

%% ============================================================
% 10. FORECAST PERIOD
% ============================================================

forecastStart = 2025;
forecastEnd   = 2035;

fprintf('\n============================================================\n');
fprintf('SOLVING DDE\n');
fprintf('============================================================\n');

fprintf('Start = %d\n',forecastStart);
fprintf('End   = %d\n',forecastEnd);
fprintf('Delay = %.2f year\n',tau);

%% ============================================================
% 11. SOLVE DDE
% ============================================================

sol = dde23( ...
    ddeFunction, ...
    tau, ...
    history, ...
    [forecastStart forecastEnd]);

fprintf('\nDDE solution completed successfully.\n');

%% ============================================================
% 12. ANNUAL FORECAST YEARS
% ============================================================

forecastYears = 2025:2035;

%% ============================================================
% 13. EVALUATE SOLUTION
% ============================================================

solution = deval(sol,forecastYears);

forecastX = solution';

%% ============================================================
% 14. CHECK RAW DDE OUTPUT
% ============================================================

fprintf('\n============================================================\n');
fprintf('RAW DDE OUTPUT\n');
fprintf('============================================================\n');

rawTable = array2table( ...
    forecastX, ...
    'VariableNames', ...
    {'Water', ...
     'Low_Vegetation', ...
     'High_Vegetation', ...
     'Built_up', ...
     'Bare_Land'});

rawTable.Year = forecastYears';

rawTable = rawTable(:, ...
    [{'Year'}, ...
     {'Water'}, ...
     {'Low_Vegetation'}, ...
     {'High_Vegetation'}, ...
     {'Built_up'}, ...
     {'Bare_Land'}]);

disp(rawTable);

%% ============================================================
% 15. REMOVE NEGATIVE VALUES
% ============================================================

forecastX_corrected = forecastX;

forecastX_corrected(forecastX_corrected < 0) = 0;

%% ============================================================
% 16. NORMALIZE PROPORTIONS
% ============================================================

forecastX_normalized = zeros(size(forecastX_corrected));

for i = 1:size(forecastX_corrected,1)

    row = forecastX_corrected(i,:);

    rowTotal = sum(row);

    if rowTotal > 0

        forecastX_normalized(i,:) = ...
            row / rowTotal;

    else

        forecastX_normalized(i,:) = ...
            NaN(1,nClasses);

    end

end

%% ============================================================
% 17. CHECK NORMALIZED VALUES
% ============================================================

normalizedSum = sum(forecastX_normalized,2);

fprintf('\n============================================================\n');
fprintf('NORMALIZED DDE OUTPUT CHECK\n');
fprintf('============================================================\n');

for i = 1:length(forecastYears)

    fprintf('%d   Sum = %.6f\n', ...
        forecastYears(i), ...
        normalizedSum(i));

end

%% ============================================================
% 18. CONVERT TO PERCENTAGES
% ============================================================

forecastPercent = ...
    forecastX_normalized * 100;

%% ============================================================
% 19. FORECAST TABLE
% ============================================================

forecastPercentTable = array2table( ...
    forecastPercent, ...
    'VariableNames', ...
    {'Water', ...
     'Low_Vegetation', ...
     'High_Vegetation', ...
     'Built_up', ...
     'Bare_Land'});

forecastPercentTable.Year = ...
    forecastYears';

forecastPercentTable = ...
    forecastPercentTable(:, ...
    [{'Year'}, ...
     {'Water'}, ...
     {'Low_Vegetation'}, ...
     {'High_Vegetation'}, ...
     {'Built_up'}, ...
     {'Bare_Land'}]);

fprintf('\n============================================================\n');
fprintf('DDE SIMULATION: 2025-2035\n');
fprintf('============================================================\n');

disp(forecastPercentTable);

%% ============================================================
% 20. 2026-2035 ONLY
% ============================================================

forecastOnly = ...
    forecastPercentTable(2:end,:);

fprintf('\n============================================================\n');
fprintf('DDE FORECAST: 2026-2035\n');
fprintf('============================================================\n');

disp(forecastOnly);

%% ============================================================
% 21. PLOT DDE FORECAST
% ============================================================

figure('Name', ...
       'LULC DDE Forecast 2025-2035', ...
       'NumberTitle','off');

plot(forecastYears, ...
     forecastPercent(:,1), ...
     '-o','LineWidth',1.5);

hold on;

plot(forecastYears, ...
     forecastPercent(:,2), ...
     '-o','LineWidth',1.5);

plot(forecastYears, ...
     forecastPercent(:,3), ...
     '-o','LineWidth',1.5);

plot(forecastYears, ...
     forecastPercent(:,4), ...
     '-o','LineWidth',1.5);

plot(forecastYears, ...
     forecastPercent(:,5), ...
     '-o','LineWidth',1.5);

xlabel('Year');

ylabel('LULC Area (%)');

title('DDE-Simulated LULC Dynamics, 2025-2035');

legend(classNames, ...
       'Location','best');

grid on;

xlim([2025 2035]);

%% ============================================================
% 22. SAVE FORECAST FIGURE
% ============================================================

forecastFigure = fullfile( ...
    dataFolder, ...
    'LULC_DDE_Forecast_2025_2035.png');

saveas(gcf,forecastFigure);

fprintf('\nForecast figure saved:\n%s\n', ...
    forecastFigure);

%% ============================================================
% 23. COMBINE OBSERVED AND FORECAST
% ============================================================

% Historical observed data:
% 2017-2025

historicalPercent = classPercent;

% Forecast:
% 2026-2035

futurePercent = forecastPercent(2:end,:);

% Combine

allPercent = ...
    [historicalPercent; futurePercent];

allYears = ...
    [years(:); (2026:2035)'];

%% ============================================================
% 24. CREATE COMBINED TABLE
% ============================================================

allTable = array2table( ...
    allPercent, ...
    'VariableNames', ...
    {'Water', ...
     'Low_Vegetation', ...
     'High_Vegetation', ...
     'Built_up', ...
     'Bare_Land'});

allTable.Year = allYears;

allTable = allTable(:, ...
    [{'Year'}, ...
     {'Water'}, ...
     {'Low_Vegetation'}, ...
     {'High_Vegetation'}, ...
     {'Built_up'}, ...
     {'Bare_Land'}]);

%% ============================================================
% 25. PLOT OBSERVED + FORECAST
% ============================================================

figure('Name', ...
       'Observed and DDE Forecast 2017-2035', ...
       'NumberTitle','off');

plot(allYears, ...
     allPercent(:,1), ...
     '-o','LineWidth',1.5);

hold on;

plot(allYears, ...
     allPercent(:,2), ...
     '-o','LineWidth',1.5);

plot(allYears, ...
     allPercent(:,3), ...
     '-o','LineWidth',1.5);

plot(allYears, ...
     allPercent(:,4), ...
     '-o','LineWidth',1.5);

plot(allYears, ...
     allPercent(:,5), ...
     '-o','LineWidth',1.5);

% 2025 boundary

yl = ylim;

plot([2025 2025], ...
     yl, ...
     '--k','LineWidth',1.5);

xlabel('Year');

ylabel('LULC Area (%)');

title('Observed 2017-2025 and DDE Forecast 2026-2035');

legend( ...
    {'Water', ...
     'Low Vegetation', ...
     'High Vegetation', ...
     'Built-up', ...
     'Bare Land', ...
     'Forecast Start'}, ...
     'Location','best');

grid on;

xlim([2017 2035]);

%% ============================================================
% 26. SAVE COMBINED FIGURE
% ============================================================

combinedFigure = fullfile( ...
    dataFolder, ...
    'LULC_Observed_DDE_Forecast_2017_2035.png');

saveas(gcf,combinedFigure);

fprintf('\nCombined figure saved:\n%s\n', ...
    combinedFigure);

%% ============================================================
% 27. CALCULATE 2025-2035 CHANGE
% ============================================================

x2035 = forecastX_normalized(end,:)';

change2035 = ...
    (x2035 - x2025) * 100;

fprintf('\n============================================================\n');
fprintf('LULC CHANGE: 2025 TO 2035\n');
fprintf('============================================================\n');

for j = 1:nClasses

    fprintf('%-20s 2025 = %8.3f%%   2035 = %8.3f%%   Change = %8.3f\n', ...
        classNames{j}, ...
        x2025(j)*100, ...
        x2035(j)*100, ...
        change2035(j));

end

%% ============================================================
% 2025 TO 2035 CHANGE
% ============================================================

% Extract 2025 and 2035 percentages
percent2025 = forecastPercent(1,:);
percent2035 = forecastPercent(end,:);

% Calculate change in percentage points
changePercent = percent2035 - percent2025;

% Create change table
changeTable = table( ...
    classNames', ...
    percent2025', ...
    percent2035', ...
    changePercent', ...
    'VariableNames', { ...
    'Class', ...
    'Percent_2025', ...
    'Percent_2035', ...
    'Change_Percentage_Point'});

disp(' ');
disp('============================================================');
disp('LULC CHANGE: 2025 TO 2035');
disp('============================================================');
disp(changeTable);

% Save table
changeFile = fullfile(dataFolder, ...
    'LULC_Change_2025_2035.csv');

writetable(changeTable,changeFile);

fprintf('\nChange table saved:\n');
fprintf('%s\n',changeFile);
%% ============================================================
% 29. SAVE FORECAST CSV
% ============================================================

forecastCSV = fullfile( ...
    dataFolder, ...
    'LULC_DDE_Forecast_2026_2035.csv');

writetable(forecastOnly,forecastCSV);

%% ============================================================
% 30. SAVE OBSERVED + FORECAST CSV
% ============================================================

allCSV = fullfile( ...
    dataFolder, ...
    'LULC_Observed_DDE_2017_2035.csv');

writetable(allTable,allCSV);

%% ============================================================
% 31. SAVE CHANGE CSV
% ============================================================

changeCSV = fullfile( ...
    dataFolder, ...
    'LULC_Change_2025_2035.csv');

writetable(changeTable,changeCSV);

%% ============================================================
% 32. SAVE STEP 3 RESULTS
% ============================================================

step3File = fullfile( ...
    dataFolder, ...
    'LULC_DDE_Step3_Results.mat');

save(step3File, ...
    'forecastYears', ...
    'forecastX', ...
    'forecastX_normalized', ...
    'forecastPercent', ...
    'forecastPercentTable', ...
    'forecastOnly', ...
    'allYears', ...
    'allPercent', ...
    'allTable', ...
    'change2035', ...
    'changeTable', ...
    'x2025', ...
    'x2035', ...
    'A', ...
    'B', ...
    'tau');

%% ============================================================
% 33. FINAL OUTPUT
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 3 COMPLETED SUCCESSFULLY\n');
fprintf('============================================================\n');

fprintf('\nFiles created:\n');

fprintf('1. LULC_DDE_Forecast_2026_2035.csv\n');
fprintf('2. LULC_Observed_DDE_2017_2035.csv\n');
fprintf('3. LULC_Change_2025_2035.csv\n');
fprintf('4. LULC_DDE_Step3_Results.mat\n');
fprintf('5. LULC_DDE_Forecast_2025_2035.png\n');
fprintf('6. LULC_Observed_DDE_Forecast_2017_2035.png\n');

fprintf('\n============================================================\n');