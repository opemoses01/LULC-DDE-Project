%% ============================================================
% STEP 4: DDE MODEL VALIDATION
% ============================================================
%
% TITLE:
% LULC Delay Differential Equation Model Validation
%
% MODEL:
% dX/dt = A*X(t) + B*X(t-tau)
%
% VALIDATION PERIOD:
% 2018-2025
%
% TRANSITIONS:
% 2017 -> 2018
% 2018 -> 2019
% ...
% 2024 -> 2025
%
% LULC CLASSES:
% 1 = Water
% 2 = Low Vegetation
% 3 = High Vegetation
% 4 = Built-up
% 5 = Bare Land
%
% MATLAB VERSION:
% MATLAB R2019a compatible
%
% TOOLBOX REQUIREMENT:
% Does NOT require Statistics and Machine Learning Toolbox
%
% INPUT:
% LULC_DDE_Model_2017_2025.mat
%
% OUTPUT:
% - DDE_Validation_Classwise_Results.csv
% - DDE_Validation_Overall_Results.csv
% - DDE_Observed_vs_Predicted_2018_2025.csv
% - DDE_Residuals_2018_2025.csv
% - DDE_Validation_Results.mat
% - DDE_Observed_vs_Predicted_Timeseries.png
% - DDE_Observed_vs_Predicted_Timeseries.fig
% - DDE_Observed_vs_Predicted_Scatter.png
% - DDE_Observed_vs_Predicted_Scatter.fig
% - DDE_Overall_Validation.png
% - DDE_Overall_Validation.fig
% - DDE_Residuals.png
% - DDE_Residuals.fig
%
% ============================================================

clear;
clc;
close all;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 4: DDE MODEL VALIDATION\n');
fprintf('============================================================\n');


%% ============================================================
% 1. DEFINE DATA FOLDER
% ============================================================

% Same folder used by Step 2

dataFolder = fileparts(mfilename('fullpath'));

fprintf('\nData folder:\n%s\n',dataFolder);


%% ============================================================
% 2. CHECK DATA FOLDER
% ============================================================

if ~exist(dataFolder,'dir')

    error(['Data folder does not exist:\n%s\n\n' ...
           'Please update dataFolder in Step 4.'], ...
           dataFolder);

end


%% ============================================================
% 3. DEFINE STEP 2 MODEL FILE
% ============================================================

modelFile = fullfile( ...
    dataFolder, ...
    'LULC_DDE_Model_2017_2025.mat');


if ~exist(modelFile,'file')

    error(['Step 2 DDE model was not found:\n%s\n\n' ...
           'Run Step 2 first or place the MAT file in the Data folder.'], ...
           modelFile);

end


%% ============================================================
% 4. LOAD STEP 2 DDE MODEL
% ============================================================

fprintf('\nLoading Step 2 DDE model...\n');

load(modelFile);

fprintf('Step 2 DDE model loaded successfully.\n');


%% ============================================================
% 5. CHECK REQUIRED VARIABLES
% ============================================================

requiredVariables = { ...
    'years', ...
    'X', ...
    'tau', ...
    'A', ...
    'B', ...
    'dX', ...
    'dX_pred', ...
    'classNames'};


for i = 1:length(requiredVariables)

    if ~exist(requiredVariables{i},'var')

        error(['Required variable "%s" was not found in the ' ...
               'Step 2 MAT file.'], ...
               requiredVariables{i});

    end

end


fprintf('\nAll required Step 2 variables are available.\n');


%% ============================================================
% 6. DISPLAY MODEL INFORMATION
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 2 DDE MODEL INFORMATION\n');
fprintf('============================================================\n');

fprintf('Model years: %d - %d\n', ...
    years(1),years(end));

fprintf('Number of years: %d\n', ...
    length(years));

fprintf('Number of LULC classes: %d\n', ...
    size(X,2));

fprintf('DDE delay: %.2f year(s)\n',tau);

fprintf('A matrix size: %d x %d\n', ...
    size(A,1),size(A,2));

fprintf('B matrix size: %d x %d\n', ...
    size(B,1),size(B,2));


%% ============================================================
% 7. DEFINE VALIDATION YEARS
% ============================================================

% Step 2 calculates:
%
% dX = X(2018)-X(2017)
%      X(2019)-X(2018)
%      ...
%      X(2025)-X(2024)
%
% Therefore, the validation year is the ENDING YEAR
% of each transition.

validationYears = years(2:end);

validationYears = validationYears(:);


%% ============================================================
% 8. PREPARE OBSERVED DATA
% ============================================================

% Step 2:
%
% dX = 8 x 5
%
% Rows:
% 2017 -> 2018
% 2018 -> 2019
% ...
% 2024 -> 2025

observed = dX;


%% ============================================================
% 9. PREPARE PREDICTED DATA
% ============================================================

% Step 2 stores:
%
% dX_pred = 5 x 8
%
% Therefore transpose it to:
%
% predicted = 8 x 5

predicted = dX_pred';


%% ============================================================
% 10. CHECK DIMENSIONS
% ============================================================

fprintf('\n');
fprintf('Observed matrix size: %d x %d\n', ...
    size(observed,1), ...
    size(observed,2));

fprintf('Predicted matrix size: %d x %d\n', ...
    size(predicted,1), ...
    size(predicted,2));


if ~isequal(size(observed),size(predicted))

    error(['Observed and predicted matrices have different ' ...
           'dimensions.']);

end


if size(observed,1) ~= length(validationYears)

    error(['Number of validation years does not match the ' ...
           'number of annual observations.']);

end


%% ============================================================
% 11. NUMBER OF CLASSES AND YEARS
% ============================================================

numYears = size(observed,1);

numClasses = size(observed,2);


fprintf('\nNumber of validation years: %d\n',numYears);

fprintf('Number of LULC classes: %d\n',numClasses);


%% ============================================================
% 12. DISPLAY CLASS NAMES
% ============================================================

fprintf('\nLULC classes:\n');

for i = 1:numClasses

    fprintf('%d. %s\n', ...
        i, ...
        classNames{i});

end


%% ============================================================
% 13. INITIALIZE METRICS
% ============================================================

RMSE = NaN(numClasses,1);

MAE = NaN(numClasses,1);

R2 = NaN(numClasses,1);

Correlation = NaN(numClasses,1);

Bias = NaN(numClasses,1);

MaxAbsoluteError = NaN(numClasses,1);


%% ============================================================
% 14. CLASS-WISE VALIDATION
%% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' CLASS-WISE DDE VALIDATION\n');
fprintf('============================================================\n');

for i = 1:numClasses

    % Extract observed and predicted values
    obs = observed(:,i);
    pred = predicted(:,i);

    % Remove NaN and Inf values
    validIdx = ~isnan(obs) & ~isnan(pred) & ...
               ~isinf(obs) & ~isinf(pred);

    obsValid = obs(validIdx);
    predValid = pred(validIdx);

    if isempty(obsValid)

        warning('No valid observations for class %s.', ...
            classNames{i});

        continue;

    end

    % RMSE
    RMSE(i) = sqrt(mean((obsValid - predValid).^2));

    % MAE
    MAE(i) = mean(abs(obsValid - predValid));

    % Bias
    Bias(i) = mean(predValid - obsValid);

    % Maximum absolute error
    MaxAbsoluteError(i) = ...
        max(abs(predValid - obsValid));

    % R-squared
    SSres = sum((obsValid - predValid).^2);
    SStot = sum((obsValid - mean(obsValid)).^2);

    if SStot ~= 0
        R2(i) = 1 - SSres/SStot;
    else
        R2(i) = NaN;
    end

    % Pearson correlation
    if length(obsValid) > 1

        obsMean = mean(obsValid);
        predMean = mean(predValid);

        numerator = sum( ...
            (obsValid - obsMean) .* ...
            (predValid - predMean));

        denominator = sqrt( ...
            sum((obsValid - obsMean).^2) * ...
            sum((predValid - predMean).^2));

        if denominator ~= 0
            Correlation(i) = numerator / denominator;
        else
            Correlation(i) = NaN;
        end

    else

        Correlation(i) = NaN;

    end

    % Display
    fprintf('\nClass: %s\n', classNames{i});
    fprintf('  RMSE              = %.6f\n', RMSE(i));
    fprintf('  MAE               = %.6f\n', MAE(i));
    fprintf('  R2                = %.6f\n', R2(i));
    fprintf('  Pearson r         = %.6f\n', Correlation(i));
    fprintf('  Bias              = %.6f\n', Bias(i));
    fprintf('  Maximum Abs Error = %.6f\n', ...
        MaxAbsoluteError(i));

end
%% ============================================================
% 15. CLASS-WISE VALIDATION TABLE
% ============================================================

ValidationResults = table( ...
    classNames(:), ...
    RMSE, ...
    MAE, ...
    R2, ...
    Correlation, ...
    Bias, ...
    MaxAbsoluteError, ...
    'VariableNames', ...
    { ...
    'LULC_Class', ...
    'RMSE', ...
    'MAE', ...
    'R2', ...
    'Correlation', ...
    'Bias', ...
    'MaxAbsoluteError' ...
    });


%% ============================================================
% 16. DISPLAY CLASS-WISE TABLE
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' CLASS-WISE VALIDATION RESULTS\n');
fprintf('============================================================\n');

disp(ValidationResults);


%% ============================================================
% 17. CALCULATE OVERALL VALIDATION
% ============================================================

% Convert matrices to vectors

obsAll = observed(:);

predAll = predicted(:);


% Remove invalid observations

validIdxAll = ...
    ~isnan(obsAll) & ...
    ~isnan(predAll) & ...
    ~isinf(obsAll) & ...
    ~isinf(predAll);


obsAll = obsAll(validIdxAll);

predAll = predAll(validIdxAll);


%% ============================================================
% 18. OVERALL RMSE
% ============================================================

Overall_RMSE = sqrt( ...
    mean((obsAll-predAll).^2));


%% ============================================================
% 19. OVERALL MAE
% ============================================================

Overall_MAE = mean( ...
    abs(obsAll-predAll));


%% ============================================================
% 20. OVERALL BIAS
% ============================================================

Overall_Bias = mean( ...
    predAll-obsAll);


%% ============================================================
% 21. OVERALL MAXIMUM ABSOLUTE ERROR
% ============================================================

Overall_MaxAbsoluteError = max( ...
    abs(obsAll-predAll));


%% ============================================================
% 22. OVERALL R-SQUARED
% ============================================================

SSresAll = sum( ...
    (obsAll-predAll).^2);


SStotAll = sum( ...
    (obsAll-mean(obsAll)).^2);


if SStotAll ~= 0

    Overall_R2 = ...
        1-(SSresAll/SStotAll);

else

    Overall_R2 = NaN;

end


%% ============================================================
% 23. OVERALL PEARSON CORRELATION
% ============================================================

if length(obsAll) > 1

    obsMeanAll = mean(obsAll);

    predMeanAll = mean(predAll);


    numeratorAll = sum( ...
        (obsAll-obsMeanAll) .* ...
        (predAll-predMeanAll));


    denominatorAll = sqrt( ...
        sum((obsAll-obsMeanAll).^2) * ...
        sum((predAll-predMeanAll).^2));


    if denominatorAll ~= 0

        Overall_Correlation = ...
            numeratorAll/denominatorAll;

    else

        Overall_Correlation = NaN;

    end

else

    Overall_Correlation = NaN;

end


%% ============================================================
% 24. OVERALL PERFORMANCE TABLE
% ============================================================

OverallResults = table( ...
    Overall_RMSE, ...
    Overall_MAE, ...
    Overall_R2, ...
    Overall_Correlation, ...
    Overall_Bias, ...
    Overall_MaxAbsoluteError, ...
    'VariableNames', ...
    { ...
    'Overall_RMSE', ...
    'Overall_MAE', ...
    'Overall_R2', ...
    'Overall_Correlation', ...
    'Overall_Bias', ...
    'Overall_MaxAbsoluteError' ...
    });


%% ============================================================
% 25. DISPLAY OVERALL PERFORMANCE
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' OVERALL DDE MODEL PERFORMANCE\n');
fprintf('============================================================\n');

disp(OverallResults);


%% ============================================================
% 26. CREATE TRANSITION LABELS
% ============================================================

Transition = cell(numYears,1);


for k = 1:numYears

    Transition{k} = sprintf( ...
        '%d-%d', ...
        years(k), ...
        years(k+1));

end


%% ============================================================
% 27. CREATE OBSERVED VS PREDICTED TABLE
% ============================================================

ObservedPredictedTable = table( ...
    validationYears, ...
    Transition, ...
    'VariableNames', ...
    {'Year','Transition'});


for i = 1:numClasses

    % Convert class name to valid MATLAB variable name

    classVar = matlab.lang.makeValidName( ...
        classNames{i});


    % Observed

    ObservedPredictedTable. ...
        ([classVar '_Observed']) = ...
        observed(:,i);


    % Predicted

    ObservedPredictedTable. ...
        ([classVar '_Predicted']) = ...
        predicted(:,i);


    % Error

    ObservedPredictedTable. ...
        ([classVar '_Error']) = ...
        predicted(:,i)-observed(:,i);

end


%% ============================================================
% 28. CREATE RESIDUAL TABLE
% ============================================================

ResidualTable = table( ...
    validationYears, ...
    Transition, ...
    'VariableNames', ...
    {'Year','Transition'});


for i = 1:numClasses

    classVar = matlab.lang.makeValidName( ...
        classNames{i});


    residual = predicted(:,i)-observed(:,i);


    ResidualTable. ...
        ([classVar '_Residual']) = residual;

end


%% ============================================================
% 29. SAVE CLASS-WISE RESULTS CSV
% ============================================================

classwiseFile = fullfile( ...
    dataFolder, ...
    'DDE_Validation_Classwise_Results.csv');


writetable( ...
    ValidationResults, ...
    classwiseFile);


fprintf('\nSaved:\n%s\n',classwiseFile);


%% ============================================================
% 30. SAVE OVERALL RESULTS CSV
% ============================================================

overallFile = fullfile( ...
    dataFolder, ...
    'DDE_Validation_Overall_Results.csv');


writetable( ...
    OverallResults, ...
    overallFile);


fprintf('Saved:\n%s\n',overallFile);


%% ============================================================
% 31. SAVE OBSERVED VS PREDICTED CSV
% ============================================================

comparisonFile = fullfile( ...
    dataFolder, ...
    'DDE_Observed_vs_Predicted_2018_2025.csv');


writetable( ...
    ObservedPredictedTable, ...
    comparisonFile);


fprintf('Saved:\n%s\n',comparisonFile);


%% ============================================================
% 32. SAVE RESIDUAL CSV
% ============================================================

residualFile = fullfile( ...
    dataFolder, ...
    'DDE_Residuals_2018_2025.csv');


writetable( ...
    ResidualTable, ...
    residualFile);


fprintf('Saved:\n%s\n',residualFile);


%% ============================================================
% 33. OBSERVED VS PREDICTED TIME-SERIES
% ============================================================

figure( ...
    'Name','DDE Observed vs Predicted Time Series', ...
    'NumberTitle','off', ...
    'Position',[100 100 1400 850]);


for i = 1:numClasses

    subplot(3,2,i);


    plot( ...
        validationYears, ...
        observed(:,i), ...
        '-o', ...
        'LineWidth',2, ...
        'MarkerSize',6);


    hold on;


    plot( ...
        validationYears, ...
        predicted(:,i), ...
        '--s', ...
        'LineWidth',2, ...
        'MarkerSize',6);


    xlabel('Ending Year');

    ylabel('Annual LULC Change');


    title(classNames{i});


    legend( ...
        'Observed', ...
        'DDE Predicted', ...
        'Location','best');


    grid on;

    xlim([validationYears(1)-0.5 ...
          validationYears(end)+0.5]);

end


sgtitle( ...
    'DDE Validation: Observed vs Predicted Annual LULC Changes (2018-2025)', ...
    'FontSize',14, ...
    'FontWeight','bold');


%% ============================================================
% 34. SAVE TIME-SERIES FIGURE
% ============================================================

timeseriesPNG = fullfile( ...
    dataFolder, ...
    'DDE_Observed_vs_Predicted_Timeseries.png');


timeseriesFIG = fullfile( ...
    dataFolder, ...
    'DDE_Observed_vs_Predicted_Timeseries.fig');


% MATLAB R2019a-compatible

print( ...
    gcf, ...
    timeseriesPNG, ...
    '-dpng', ...
    '-r300');


savefig( ...
    gcf, ...
    timeseriesFIG);


fprintf('\nTime-series figure saved.\n');


%% ============================================================
% 35. CLASS-WISE SCATTER PLOTS
% ============================================================

figure( ...
    'Name','Observed vs DDE Predicted Scatter', ...
    'NumberTitle','off', ...
    'Position',[100 100 1400 850]);


for i = 1:numClasses

    subplot(3,2,i);


    obs = observed(:,i);

    pred = predicted(:,i);


    validIdx = ...
        ~isnan(obs) & ...
        ~isnan(pred) & ...
        ~isinf(obs) & ...
        ~isinf(pred);


    obs = obs(validIdx);

    pred = pred(validIdx);


    scatter( ...
        obs, ...
        pred, ...
        70, ...
        'filled');


    hold on;


    minVal = min([obs;pred]);

    maxVal = max([obs;pred]);


    if minVal == maxVal

        minVal = minVal-0.01;

        maxVal = maxVal+0.01;

    end


    plot( ...
        [minVal maxVal], ...
        [minVal maxVal], ...
        '--', ...
        'LineWidth',1.5);


    xlabel('Observed Annual Change');

    ylabel('DDE Predicted Annual Change');


    title({ ...
        classNames{i}, ...
        sprintf('R^2 = %.3f, RMSE = %.4f', ...
        R2(i),RMSE(i))});


    legend( ...
        'Observed vs Predicted', ...
        '1:1 Reference', ...
        'Location','best');


    grid on;


    axis equal;


    xlim([minVal maxVal]);

    ylim([minVal maxVal]);

end


sgtitle( ...
    'Observed vs DDE-Predicted Annual LULC Changes', ...
    'FontSize',14, ...
    'FontWeight','bold');


%% ============================================================
% 36. SAVE CLASS-WISE SCATTER FIGURE
% ============================================================

scatterPNG = fullfile( ...
    dataFolder, ...
    'DDE_Observed_vs_Predicted_Scatter.png');


scatterFIG = fullfile( ...
    dataFolder, ...
    'DDE_Observed_vs_Predicted_Scatter.fig');


print( ...
    gcf, ...
    scatterPNG, ...
    '-dpng', ...
    '-r300');


savefig( ...
    gcf, ...
    scatterFIG);


fprintf('Scatter figure saved.\n');


%% ============================================================
% 37. OVERALL SCATTER PLOT
% ============================================================

figure( ...
    'Name','Overall DDE Validation', ...
    'NumberTitle','off', ...
    'Position',[300 150 900 750]);


scatter( ...
    obsAll, ...
    predAll, ...
    70, ...
    'filled');


hold on;


minValAll = min([obsAll;predAll]);

maxValAll = max([obsAll;predAll]);


if minValAll == maxValAll

    minValAll = minValAll-0.01;

    maxValAll = maxValAll+0.01;

end


plot( ...
    [minValAll maxValAll], ...
    [minValAll maxValAll], ...
    '--', ...
    'LineWidth',2);


xlabel('Observed Annual LULC Change');

ylabel('DDE Predicted Annual LULC Change');


title({ ...
    'Overall DDE Model Validation', ...
    sprintf('RMSE = %.4f   MAE = %.4f', ...
    Overall_RMSE,Overall_MAE), ...
    sprintf('R^2 = %.3f   Pearson r = %.3f', ...
    Overall_R2,Overall_Correlation)});


legend( ...
    'Observed vs Predicted', ...
    '1:1 Reference Line', ...
    'Location','best');


grid on;

axis equal;


xlim([minValAll maxValAll]);

ylim([minValAll maxValAll]);


%% ============================================================
% 38. SAVE OVERALL SCATTER
% ============================================================

overallPNG = fullfile( ...
    dataFolder, ...
    'DDE_Overall_Validation.png');


overallFIG = fullfile( ...
    dataFolder, ...
    'DDE_Overall_Validation.fig');


print( ...
    gcf, ...
    overallPNG, ...
    '-dpng', ...
    '-r300');


savefig( ...
    gcf, ...
    overallFIG);


fprintf('Overall validation figure saved.\n');


%% ============================================================
% 39. RESIDUAL / ERROR PLOT
% ============================================================

figure( ...
    'Name','DDE Residual Analysis', ...
    'NumberTitle','off', ...
    'Position',[100 100 1400 850]);


for i = 1:numClasses

    subplot(3,2,i);


    residual = ...
        predicted(:,i)-observed(:,i);


    plot( ...
        validationYears, ...
        residual, ...
        '-o', ...
        'LineWidth',2, ...
        'MarkerSize',6);


    hold on;


    plot( ...
        [validationYears(1) validationYears(end)], ...
        [0 0], ...
        '--', ...
        'LineWidth',1.5);


    xlabel('Ending Year');

    ylabel('Prediction Error');


    title(classNames{i});


    grid on;


    xlim([validationYears(1)-0.5 ...
          validationYears(end)+0.5]);

end


sgtitle( ...
    'DDE Prediction Residuals (Predicted - Observed)', ...
    'FontSize',14, ...
    'FontWeight','bold');


%% ============================================================
% 40. SAVE RESIDUAL FIGURE
% ============================================================

residualPNG = fullfile( ...
    dataFolder, ...
    'DDE_Residuals.png');


residualFIG = fullfile( ...
    dataFolder, ...
    'DDE_Residuals.fig');


print( ...
    gcf, ...
    residualPNG, ...
    '-dpng', ...
    '-r300');


savefig( ...
    gcf, ...
    residualFIG);


fprintf('Residual figure saved.\n');


%% ============================================================
% 41. CALCULATE YEAR-BY-YEAR OVERALL ERROR
% ============================================================

Year_RMSE = NaN(numYears,1);

Year_MAE = NaN(numYears,1);

Year_Bias = NaN(numYears,1);


for k = 1:numYears

    obsYear = observed(k,:);

    predYear = predicted(k,:);


    validIdx = ...
        ~isnan(obsYear) & ...
        ~isnan(predYear) & ...
        ~isinf(obsYear) & ...
        ~isinf(predYear);


    obsYear = obsYear(validIdx);

    predYear = predYear(validIdx);


    if ~isempty(obsYear)

        Year_RMSE(k) = sqrt( ...
            mean((obsYear-predYear).^2));


        Year_MAE(k) = mean( ...
            abs(obsYear-predYear));


        Year_Bias(k) = mean( ...
            predYear-obsYear);

    end

end


%% ============================================================
% 42. YEARLY VALIDATION TABLE
% ============================================================

YearlyResults = table( ...
    validationYears, ...
    Transition, ...
    Year_RMSE, ...
    Year_MAE, ...
    Year_Bias, ...
    'VariableNames', ...
    { ...
    'Year', ...
    'Transition', ...
    'RMSE', ...
    'MAE', ...
    'Bias' ...
    });


%% ============================================================
% 43. SAVE YEARLY RESULTS
% ============================================================

yearlyFile = fullfile( ...
    dataFolder, ...
    'DDE_Validation_Yearly_Results.csv');


writetable( ...
    YearlyResults, ...
    yearlyFile);


fprintf('Yearly validation results saved.\n');


%% ============================================================
% 44. SAVE COMPLETE MAT RESULTS
% ============================================================

validationMAT = fullfile( ...
    dataFolder, ...
    'DDE_Validation_Results.mat');


save( ...
    validationMAT, ...
    'ValidationResults', ...
    'OverallResults', ...
    'ObservedPredictedTable', ...
    'ResidualTable', ...
    'YearlyResults', ...
    'observed', ...
    'predicted', ...
    'validationYears', ...
    'Transition', ...
    'RMSE', ...
    'MAE', ...
    'R2', ...
    'Correlation', ...
    'Bias', ...
    'MaxAbsoluteError', ...
    'Overall_RMSE', ...
    'Overall_MAE', ...
    'Overall_R2', ...
    'Overall_Correlation', ...
    'Overall_Bias', ...
    'Overall_MaxAbsoluteError', ...
    'Year_RMSE', ...
    'Year_MAE', ...
    'Year_Bias');


fprintf('\nComplete validation MAT file saved:\n%s\n', ...
    validationMAT);


%% ============================================================
% 45. DISPLAY DDE MATRICES
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' INSTANTANEOUS INTERACTION MATRIX A\n');
fprintf('============================================================\n');

disp(A);


fprintf('\n');
fprintf('============================================================\n');
fprintf(' DELAYED INTERACTION MATRIX B\n');
fprintf('============================================================\n');

disp(B);


%% ============================================================
% 46. DISPLAY FINAL PERFORMANCE SUMMARY
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' FINAL DDE VALIDATION SUMMARY\n');
fprintf('============================================================\n');


fprintf('\nOverall RMSE              = %.6f\n', ...
    Overall_RMSE);


fprintf('Overall MAE               = %.6f\n', ...
    Overall_MAE);


fprintf('Overall R2                = %.6f\n', ...
    Overall_R2);


fprintf('Overall Pearson r         = %.6f\n', ...
    Overall_Correlation);


fprintf('Overall Bias              = %.6f\n', ...
    Overall_Bias);


fprintf('Overall Max Abs Error     = %.6f\n', ...
    Overall_MaxAbsoluteError);


fprintf('\n');


%% ============================================================
% 47. CLASS PERFORMANCE SUMMARY
% ============================================================

fprintf('------------------------------------------------------------\n');

fprintf('%-20s %10s %10s %10s %10s\n', ...
    'Class', ...
    'RMSE', ...
    'MAE', ...
    'R2', ...
    'Pearson r');


fprintf('------------------------------------------------------------\n');


for i = 1:numClasses

    fprintf('%-20s %10.5f %10.5f %10.5f %10.5f\n', ...
        classNames{i}, ...
        RMSE(i), ...
        MAE(i), ...
        R2(i), ...
        Correlation(i));

end


fprintf('------------------------------------------------------------\n');


%% ============================================================
% 48. FINAL FILE LIST
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf(' STEP 4 COMPLETED SUCCESSFULLY\n');
fprintf('============================================================\n');


fprintf('\nGenerated files:\n\n');


fprintf('1. DDE_Validation_Classwise_Results.csv\n');

fprintf('2. DDE_Validation_Overall_Results.csv\n');

fprintf('3. DDE_Observed_vs_Predicted_2018_2025.csv\n');

fprintf('4. DDE_Residuals_2018_2025.csv\n');

fprintf('5. DDE_Validation_Yearly_Results.csv\n');

fprintf('6. DDE_Validation_Results.mat\n');

fprintf('7. DDE_Observed_vs_Predicted_Timeseries.png\n');

fprintf('8. DDE_Observed_vs_Predicted_Timeseries.fig\n');

fprintf('9. DDE_Observed_vs_Predicted_Scatter.png\n');

fprintf('10. DDE_Observed_vs_Predicted_Scatter.fig\n');

fprintf('11. DDE_Overall_Validation.png\n');

fprintf('12. DDE_Overall_Validation.fig\n');

fprintf('13. DDE_Residuals.png\n');

fprintf('14. DDE_Residuals.fig\n');


fprintf('\n============================================================\n');
fprintf(' VALIDATION PERIOD: 2018-2025\n');
fprintf(' DDE DELAY: %.2f YEAR\n',tau);
fprintf(' LULC CLASSES: %d\n',numClasses);
fprintf('============================================================\n');


fprintf('\nNext stage:\n');
fprintf('STEP 5 = Interpret DDE dynamics and model performance.\n');

fprintf('\n============================================================\n');