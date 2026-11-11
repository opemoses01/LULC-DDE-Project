%% ================================================================
% STEP 4 - DDE VALIDATION USING GEOTIFF RASTERS
% 2018 - 2025
%
% Calculates:
%   1. RMSE
%   2. MAE
%   3. R2
%   4. Correlation coefficient
%
% Produces:
%   - Observed maps
%   - DDE predicted maps
%   - Error maps
%   - Observed vs predicted scatter plots
%   - Validation metrics CSV
%   - Error GeoTIFFs
%
% Compatible with older MATLAB versions
% Does NOT require Statistics and Machine Learning Toolbox
% Does NOT use exportgraphics
%% ================================================================

clear;
clc;
close all;

%% ================================================================
% 1. USER SETTINGS
%% ================================================================

% Main project folder
projectFolder = fileparts(mfilename('fullpath'));

% Observed GeoTIFF folder
observedFolder = fullfile(projectFolder,'observed');

% Predicted GeoTIFF folder
predictedFolder = fullfile(projectFolder,'predicted');

% Output folders
outputFolder = fullfile(projectFolder,'Step4_DDE_Validation');

mapFolder = fullfile(outputFolder,'Maps');
figureFolder = fullfile(outputFolder,'Figures');
resultFolder = fullfile(outputFolder,'Results');

% Create folders if they do not exist
if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end

if ~exist(mapFolder,'dir')
    mkdir(mapFolder);
end

if ~exist(figureFolder,'dir')
    mkdir(figureFolder);
end

if ~exist(resultFolder,'dir')
    mkdir(resultFolder);
end

% Years to validate
years = 2018:2025;

% ---------------------------------------------------------------
% CHANGE THESE IF YOUR FILENAMES ARE DIFFERENT
% ---------------------------------------------------------------
observedPrefix = 'Observed_';
predictedPrefix = 'Predicted_';
fileExtension = '.tif';


%% ================================================================
% 2. INITIALIZE RESULTS
%% ================================================================

nYears = length(years);

RMSE = NaN(nYears,1);
MAE = NaN(nYears,1);
R2 = NaN(nYears,1);
Correlation = NaN(nYears,1);

MeanObserved = NaN(nYears,1);
MeanPredicted = NaN(nYears,1);

StdObserved = NaN(nYears,1);
StdPredicted = NaN(nYears,1);

MinObserved = NaN(nYears,1);
MaxObserved = NaN(nYears,1);

MinPredicted = NaN(nYears,1);
MaxPredicted = NaN(nYears,1);

NumberOfPixels = zeros(nYears,1);


%% ================================================================
% 3. LOOP THROUGH YEARS
%% ================================================================

for i = 1:nYears

    year = years(i);

    fprintf('\n================================================\n');
    fprintf('Processing year: %d\n',year);
    fprintf('================================================\n');

    %% ------------------------------------------------------------
    % File names
    %% ------------------------------------------------------------

    observedFile = fullfile( ...
        observedFolder, ...
        [observedPrefix num2str(year) fileExtension]);

    predictedFile = fullfile( ...
        predictedFolder, ...
        [predictedPrefix num2str(year) fileExtension]);


    %% ------------------------------------------------------------
    % Check files
    %% ------------------------------------------------------------

    if ~exist(observedFile,'file')

        warning('Observed file not found: %s',observedFile);

        continue;

    end

    if ~exist(predictedFile,'file')

        warning('Predicted file not found: %s',predictedFile);

        continue;

    end


    %% ------------------------------------------------------------
    % Read observed GeoTIFF
    %% ------------------------------------------------------------

    try

        [observed,Robs] = geotiffread(observedFile);

    catch ME

        warning('Could not read observed file for %d.',year);
        warning('%s',ME.message);

        continue;

    end


    %% ------------------------------------------------------------
    % Read predicted GeoTIFF
    %% ------------------------------------------------------------

    try

        [predicted,Rpred] = geotiffread(predictedFile);

    catch ME

        warning('Could not read predicted file for %d.',year);
        warning('%s',ME.message);

        continue;

    end


    %% ------------------------------------------------------------
    % Convert to double
    %% ------------------------------------------------------------

    observed = double(observed);
    predicted = double(predicted);


    %% ------------------------------------------------------------
    % Check raster dimensions
    %% ------------------------------------------------------------

    if ~isequal(size(observed),size(predicted))

        warning('Raster dimensions do not match for %d.',year);

        fprintf('Observed size: ');
        disp(size(observed));

        fprintf('Predicted size: ');
        disp(size(predicted));

        continue;

    end


    %% ============================================================
    % 4. CREATE VALID PIXEL MASK
    %% ============================================================

    validMask = isfinite(observed) & isfinite(predicted);

    % Remove zero values if zero represents NoData
    %
    % COMMENT THESE TWO LINES if zero is a valid value.
    %
    validMask = validMask & observed ~= 0;
    validMask = validMask & predicted ~= 0;


    %% ------------------------------------------------------------
    % Extract valid pixels
    %% ------------------------------------------------------------

    obs = observed(validMask);
    pred = predicted(validMask);

    NumberOfPixels(i) = length(obs);


    %% ------------------------------------------------------------
    % Check whether enough pixels exist
    %% ------------------------------------------------------------

    if length(obs) < 2

        warning('Not enough valid pixels for year %d.',year);

        continue;

    end


    %% ============================================================
    % 5. ERROR CALCULATIONS
    %% ============================================================

    errorRaster = observed - predicted;

    absoluteError = abs(errorRaster);

    squaredError = errorRaster.^2;


    %% ------------------------------------------------------------
    % RMSE
    %% ------------------------------------------------------------

    RMSE(i) = sqrt(mean(squaredError(validMask)));


    %% ------------------------------------------------------------
    % MAE
    %% ------------------------------------------------------------

    MAE(i) = mean(absoluteError(validMask));


    %% ============================================================
    % 6. R-SQUARED
    %% ============================================================

    % Mean observed value
    meanObs = mean(obs);

    % Total sum of squares
    SST = sum((obs - meanObs).^2);

    % Residual sum of squares
    SSE = sum((obs - pred).^2);

    if SST ~= 0

        R2(i) = 1 - (SSE/SST);

    else

        R2(i) = NaN;

    end


    %% ============================================================
    % 7. MANUAL CORRELATION COEFFICIENT
    % No Statistics Toolbox required
    %% ============================================================

    meanPred = mean(pred);

    numerator = sum((obs - meanObs) .* ...
                    (pred - meanPred));

    denominator = sqrt( ...
        sum((obs - meanObs).^2) * ...
        sum((pred - meanPred).^2));

    if denominator ~= 0

        Correlation(i) = numerator / denominator;

    else

        Correlation(i) = NaN;

    end


    %% ============================================================
    % 8. DESCRIPTIVE STATISTICS
    %% ============================================================

    MeanObserved(i) = mean(obs);
    MeanPredicted(i) = mean(pred);

    StdObserved(i) = std(obs);
    StdPredicted(i) = std(pred);

    MinObserved(i) = min(obs);
    MaxObserved(i) = max(obs);

    MinPredicted(i) = min(pred);
    MaxPredicted(i) = max(pred);


    %% ============================================================
    % 9. DISPLAY STATISTICS
    %% ============================================================

    fprintf('\nYear: %d\n',year);
    fprintf('Valid pixels       : %d\n',NumberOfPixels(i));
    fprintf('RMSE               : %.6f\n',RMSE(i));
    fprintf('MAE                : %.6f\n',MAE(i));
    fprintf('R2                 : %.6f\n',R2(i));
    fprintf('Correlation        : %.6f\n',Correlation(i));
    fprintf('Mean Observed      : %.6f\n',MeanObserved(i));
    fprintf('Mean Predicted     : %.6f\n',MeanPredicted(i));


    %% ============================================================
    % 10. OBSERVED MAP
    %% ============================================================

    figure('Name',['Observed ' num2str(year)], ...
           'NumberTitle','off');

    mapshow(observed,Robs);

    axis image;

    title(['Observed ' num2str(year)], ...
          'FontSize',12);

    colorbar;

    xlabel('Longitude / X');
    ylabel('Latitude / Y');


    % Save using PRINT - compatible with older MATLAB
    set(gcf,'PaperPositionMode','auto');

    print(gcf, ...
        fullfile(figureFolder, ...
        ['Observed_' num2str(year) '.png']), ...
        '-dpng','-r300');

    close(gcf);


    %% ============================================================
    % 11. DDE PREDICTED MAP
    %% ============================================================

    figure('Name',['DDE Predicted ' num2str(year)], ...
           'NumberTitle','off');

    mapshow(predicted,Rpred);

    axis image;

    title(['DDE Predicted ' num2str(year)], ...
          'FontSize',12);

    colorbar;

    xlabel('Longitude / X');
    ylabel('Latitude / Y');


    set(gcf,'PaperPositionMode','auto');

    print(gcf, ...
        fullfile(figureFolder, ...
        ['DDE_Predicted_' num2str(year) '.png']), ...
        '-dpng','-r300');

    close(gcf);


    %% ============================================================
    % 12. ERROR MAP
    %% ============================================================

    figure('Name',['DDE Error ' num2str(year)], ...
           'NumberTitle','off');

    mapshow(errorRaster,Robs);

    axis image;

    title(['DDE Prediction Error ' num2str(year)], ...
          'FontSize',12);

    colorbar;

    xlabel('Longitude / X');
    ylabel('Latitude / Y');


    set(gcf,'PaperPositionMode','auto');

    print(gcf, ...
        fullfile(figureFolder, ...
        ['DDE_Error_' num2str(year) '.png']), ...
        '-dpng','-r300');

    close(gcf);


    %% ============================================================
    % 13. SAVE ERROR GEOTIFF
    %% ============================================================

    errorFile = fullfile( ...
        mapFolder, ...
        ['DDE_Error_' num2str(year) '.tif']);


    try

        % Attempt to preserve geographic reference
        geotiffwrite(errorFile,errorRaster,Robs);

        fprintf('Error GeoTIFF saved:\n%s\n',errorFile);

    catch

        warning('Could not write GeoTIFF for %d.',year);

    end


    %% ============================================================
    % 14. OBSERVED VS PREDICTED SCATTER PLOT
    %% ============================================================

    figure('Name',['Observed vs Predicted ' num2str(year)], ...
           'NumberTitle','off');

    plot(obs,pred,'.');

    hold on;


    %% ------------------------------------------------------------
    % Regression line calculated manually
    %% ------------------------------------------------------------

    xMean = mean(obs);
    yMean = mean(pred);

    slope = sum((obs-xMean).*(pred-yMean)) / ...
            sum((obs-xMean).^2);

    intercept = yMean - slope*xMean;

    xLine = linspace(min(obs),max(obs),100);

    yLine = intercept + slope*xLine;

    plot(xLine,yLine,'LineWidth',2);


    %% ------------------------------------------------------------
    % 1:1 line
    %% ------------------------------------------------------------

    minimumValue = min([obs;pred]);
    maximumValue = max([obs;pred]);

    plot([minimumValue maximumValue], ...
         [minimumValue maximumValue], ...
         '--','LineWidth',1.5);


    xlabel('Observed');
    ylabel('DDE Predicted');

    title(['Observed vs DDE Predicted - ' num2str(year)]);

    legend('Pixels','Regression','1:1 Line', ...
           'Location','best');

    grid on;


    %% ------------------------------------------------------------
    % Add statistics to plot
    %% ------------------------------------------------------------

    textPositionX = minimumValue + ...
        0.05*(maximumValue-minimumValue);

    textPositionY = maximumValue - ...
        0.10*(maximumValue-minimumValue);

    text(textPositionX,textPositionY, ...
        sprintf('RMSE = %.4f\nMAE = %.4f\nR^2 = %.4f\nr = %.4f', ...
        RMSE(i),MAE(i),R2(i),Correlation(i)));


    %% ------------------------------------------------------------
    % Save figure
    %% ------------------------------------------------------------

    set(gcf,'PaperPositionMode','auto');

    print(gcf, ...
        fullfile(figureFolder, ...
        ['Observed_vs_Predicted_' num2str(year) '.png']), ...
        '-dpng','-r300');

    close(gcf);


end


%% ================================================================
% 15. CREATE RESULTS TABLE
%% ================================================================

ResultsTable = table( ...
    years', ...
    NumberOfPixels, ...
    MeanObserved, ...
    MeanPredicted, ...
    StdObserved, ...
    StdPredicted, ...
    MinObserved, ...
    MaxObserved, ...
    MinPredicted, ...
    MaxPredicted, ...
    RMSE, ...
    MAE, ...
    R2, ...
    Correlation, ...
    'VariableNames',{ ...
    'Year', ...
    'ValidPixels', ...
    'MeanObserved', ...
    'MeanPredicted', ...
    'StdObserved', ...
    'StdPredicted', ...
    'MinObserved', ...
    'MaxObserved', ...
    'MinPredicted', ...
    'MaxPredicted', ...
    'RMSE', ...
    'MAE', ...
    'R2', ...
    'Correlation'});


%% ================================================================
% 16. DISPLAY RESULTS TABLE
%% ================================================================

fprintf('\n\n============================================================\n');
fprintf('DDE VALIDATION RESULTS\n');
fprintf('============================================================\n');

disp(ResultsTable);


%% ================================================================
% 17. SAVE RESULTS TO CSV
%% ================================================================

csvFile = fullfile( ...
    resultFolder, ...
    'DDE_Validation_Metrics_2018_2025.csv');

try

    writetable(ResultsTable,csvFile);

    fprintf('\nResults saved to:\n%s\n',csvFile);

catch

    % Older MATLAB alternative
    csvwrite(csvFile,table2array(ResultsTable));

    fprintf('\nNumeric results saved to:\n%s\n',csvFile);

end


%% ================================================================
% 18. RMSE BY YEAR
%% ================================================================

figure('Name','RMSE 2018-2025', ...
       'NumberTitle','off');

plot(years,RMSE,'-o','LineWidth',1.5);

xlabel('Year');
ylabel('RMSE');

title('DDE Validation RMSE, 2018-2025');

grid on;

xlim([min(years) max(years)]);

set(gcf,'PaperPositionMode','auto');

print(gcf, ...
    fullfile(figureFolder,'RMSE_2018_2025.png'), ...
    '-dpng','-r300');

close(gcf);


%% ================================================================
% 19. MAE BY YEAR
%% ================================================================

figure('Name','MAE 2018-2025', ...
       'NumberTitle','off');

plot(years,MAE,'-o','LineWidth',1.5);

xlabel('Year');
ylabel('MAE');

title('DDE Validation MAE, 2018-2025');

grid on;

xlim([min(years) max(years)]);

set(gcf,'PaperPositionMode','auto');

print(gcf, ...
    fullfile(figureFolder,'MAE_2018_2025.png'), ...
    '-dpng','-r300');

close(gcf);


%% ================================================================
% 20. R2 BY YEAR
%% ================================================================

figure('Name','R2 2018-2025', ...
       'NumberTitle','off');

plot(years,R2,'-o','LineWidth',1.5);

xlabel('Year');
ylabel('R^2');

title('DDE Validation R^2, 2018-2025');

grid on;

xlim([min(years) max(years)]);

set(gcf,'PaperPositionMode','auto');

print(gcf, ...
    fullfile(figureFolder,'R2_2018_2025.png'), ...
    '-dpng','-r300');

close(gcf);


%% ================================================================
% 21. CORRELATION BY YEAR
%% ================================================================

figure('Name','Correlation 2018-2025', ...
       'NumberTitle','off');

plot(years,Correlation,'-o','LineWidth',1.5);

xlabel('Year');
ylabel('Correlation coefficient');

title('Observed vs DDE Predicted Correlation, 2018-2025');

grid on;

xlim([min(years) max(years)]);

set(gcf,'PaperPositionMode','auto');

print(gcf, ...
    fullfile(figureFolder,'Correlation_2018_2025.png'), ...
    '-dpng','-r300');

close(gcf);


%% ================================================================
% 22. COMBINED VALIDATION FIGURE
%% ================================================================

figure('Name','DDE Validation Summary', ...
       'NumberTitle','off');

plot(years,RMSE,'-o','LineWidth',1.5);

hold on;

plot(years,MAE,'-s','LineWidth',1.5);

xlabel('Year');
ylabel('Error');

title('DDE Validation Error: 2018-2025');

legend('RMSE','MAE','Location','best');

grid on;

xlim([min(years) max(years)]);

set(gcf,'PaperPositionMode','auto');

print(gcf, ...
    fullfile(figureFolder, ...
    'DDE_Validation_Error_Summary.png'), ...
    '-dpng','-r300');

close(gcf);


%% ================================================================
% 23. OVERALL STATISTICS
%% ================================================================

validRMSE = RMSE(isfinite(RMSE));
validMAE = MAE(isfinite(MAE));
validR2 = R2(isfinite(R2));
validCorr = Correlation(isfinite(Correlation));


fprintf('\n\n============================================================\n');
fprintf('OVERALL DDE VALIDATION\n');
fprintf('============================================================\n');


if ~isempty(validRMSE)

    fprintf('Mean RMSE       = %.6f\n',mean(validRMSE));

end


if ~isempty(validMAE)

    fprintf('Mean MAE        = %.6f\n',mean(validMAE));

end


if ~isempty(validR2)

    fprintf('Mean R2         = %.6f\n',mean(validR2));

end


if ~isempty(validCorr)

    fprintf('Mean Correlation= %.6f\n',mean(validCorr));

end


%% ================================================================
% 24. BEST AND WORST YEARS
%% ================================================================

if ~isempty(validRMSE)

    [~,bestIndex] = min(RMSE);
    [~,worstIndex] = max(RMSE);

    fprintf('\nBest RMSE year  = %d\n',years(bestIndex));
    fprintf('Best RMSE       = %.6f\n',RMSE(bestIndex));

    fprintf('\nWorst RMSE year = %d\n',years(worstIndex));
    fprintf('Worst RMSE      = %.6f\n',RMSE(worstIndex));

end


if ~isempty(validR2)

    [~,bestR2Index] = max(R2);

    fprintf('\nBest R2 year    = %d\n',years(bestR2Index));
    fprintf('Best R2         = %.6f\n',R2(bestR2Index));

end


%% ================================================================
% 25. FINISH
%% ================================================================

fprintf('\n============================================================\n');
fprintf('STEP 4 DDE VALIDATION COMPLETED\n');
fprintf('============================================================\n');

fprintf('\nOutput folder:\n%s\n',outputFolder);

fprintf('\nMaps folder:\n%s\n',mapFolder);

fprintf('\nFigures folder:\n%s\n',figureFolder);

fprintf('\nResults folder:\n%s\n',resultFolder);

fprintf('\n============================================================\n');