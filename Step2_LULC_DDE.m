%% ============================================================
% STEP 2: 5-CLASS LULC DELAY DIFFERENTIAL EQUATION MODEL
% MATLAB R2019a
%
% Classes:
% 1 = Water
% 2 = Low Vegetation
% 3 = High Vegetation
% 4 = Built-up
% 5 = Bare Land
%
% Period:
% 2017-2025
%
% Delay:
% 1 year
%
% INPUT:
% LULC_DDE_Input_2017_2025.mat
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
fprintf('STEP 2: LULC DELAY DIFFERENTIAL EQUATION MODEL\n');
fprintf('============================================================\n');

%% ============================================================
% 2. LOAD STEP 1 DATA
% ============================================================

inputFile = fullfile(dataFolder, ...
    'LULC_DDE_Input_2017_2025.mat');

if ~exist(inputFile,'file')

    error(['Input file not found:\n%s\n\n' ...
           'Run Step 1 first.'],inputFile);

end

load(inputFile);

fprintf('\nStep 1 data loaded successfully.\n');

%% ============================================================
% 3. CHECK DATA
% ============================================================

fprintf('\nYears:\n');
disp(years);

fprintf('\nLULC proportions:\n');
disp(X);

[nYears,nClasses] = size(X);

if nClasses ~= 5

    error('The model requires exactly 5 LULC classes.');

end

if nYears < 3

    error('At least 3 years of observations are required.');

end

%% ============================================================
% 4. CLASS NAMES
% ============================================================

classNames = {'Water', ...
              'Low Vegetation', ...
              'High Vegetation', ...
              'Built-up', ...
              'Bare Land'};

%% ============================================================
% 5. CHECK THAT PROPORTIONS SUM TO 1
% ============================================================

rowSum = sum(X,2);

fprintf('\nChecking proportions...\n');

for i = 1:nYears

    fprintf('%d = %.6f\n', ...
        years(i),rowSum(i));

end

if any(abs(rowSum - 1) > 0.01)

    warning(['Some years do not sum to 1. ' ...
             'Check Step 1 results.']);

end

%% ============================================================
% 6. DEFINE TIME
% ============================================================

% Annual observations

tData = years - years(1);

% Convert to column vector

tData = tData(:);

%% ============================================================
% 7. DEFINE DELAY
% ============================================================

% One-year delay

tau = 1;

fprintf('\nDDE delay = %.2f year\n',tau);

%% ============================================================
% 8. CALCULATE OBSERVED ANNUAL CHANGE
% ============================================================

% dX/dt approximately estimated from annual observations

dX = diff(X);

dt = diff(years(:));

for i = 1:length(dt)

    dX(i,:) = dX(i,:) ./ dt(i);

end

fprintf('\nObserved annual changes:\n');

disp(dX);

%% ============================================================
% 9. CONSTRUCT DELAYED DATA
% ============================================================

% For each year after the first year:
%
% current state = X(t)
% delayed state = X(t-tau)
%
% Since tau = 1 year, the delayed state is simply the
% previous year's LULC proportion.

X_current = X(2:end,:);

X_delay = X(1:end-1,:);

fprintf('\nCurrent-state matrix:\n');

disp(X_current);

fprintf('\nDelayed-state matrix:\n');

disp(X_delay);

%% ============================================================
% 10. ESTIMATE A SIMPLE LINEAR DDE MODEL
% ============================================================

% Model:
%
% dX_i/dt = A*X(t) + B*X(t-tau)
%
% where:
%
% A = instantaneous interaction matrix
% B = delayed interaction matrix
%
% Because only 9 observations are available, we use
% ridge regression to stabilize the parameter estimation.

Y = dX';

% Create predictor matrix:
%
% [X(t) ; X(t-tau)]

P = [X_current X_delay]';

%% ============================================================
% 11. RIDGE REGULARIZATION
% ============================================================

lambda = 0.01;

fprintf('\nRidge regularization parameter = %.4f\n',lambda);

%% ============================================================
% 12. ESTIMATE DDE COEFFICIENT MATRIX
% ============================================================

% Coefficient matrix:
%
% C = [A B]

C = Y * P' / ...
    (P * P' + lambda * eye(size(P,1)));

%% ============================================================
% 13. EXTRACT A AND B
% ============================================================

A = C(:,1:nClasses);

B = C(:,nClasses+1:2*nClasses);

fprintf('\n============================================================\n');
fprintf('INSTANTANEOUS INTERACTION MATRIX A\n');
fprintf('============================================================\n');

disp(A);

fprintf('\n============================================================\n');
fprintf('DELAYED INTERACTION MATRIX B\n');
fprintf('============================================================\n');

disp(B);

%% ============================================================
% 14. CHECK MODEL PREDICTED DERIVATIVES
% ============================================================

dX_pred = zeros(size(Y));

for k = 1:size(X_current,1)

    currentState = X_current(k,:)';

    delayedState = X_delay(k,:)';

    dX_pred(:,k) = ...
        A * currentState + ...
        B * delayedState;

end

%% ============================================================
% 15. OBSERVED VS PREDICTED CHANGE
% ============================================================

fprintf('\n============================================================\n');
fprintf('OBSERVED VS PREDICTED ANNUAL CHANGE\n');
fprintf('============================================================\n');

for k = 1:size(dX,1)

    fprintf('\nYear %d -> %d\n', ...
        years(k),years(k+1));

    for j = 1:nClasses

        fprintf('%-20s Observed = %8.5f   Predicted = %8.5f\n', ...
            classNames{j}, ...
            Y(j,k), ...
            dX_pred(j,k));

    end

end

%% ============================================================
% 16. CALCULATE RMSE
% ============================================================

rmse = zeros(nClasses,1);

for j = 1:nClasses

    rmse(j) = sqrt(mean( ...
        (Y(j,:) - dX_pred(j,:)).^2 ));

end

fprintf('\n============================================================\n');
fprintf('DDE RMSE\n');
fprintf('============================================================\n');

for j = 1:nClasses

    fprintf('%-20s RMSE = %.6f\n', ...
        classNames{j},rmse(j));

end

%% ============================================================
% 17. CALCULATE R-SQUARED
% ============================================================

R2 = zeros(nClasses,1);

for j = 1:nClasses

    observed = Y(j,:);

    predicted = dX_pred(j,:);

    SSres = sum((observed-predicted).^2);

    SStot = sum((observed-mean(observed)).^2);

    if SStot == 0

        R2(j) = NaN;

    else

        R2(j) = 1 - SSres/SStot;

    end

end

fprintf('\n============================================================\n');
fprintf('DDE R-SQUARED\n');
fprintf('============================================================\n');

for j = 1:nClasses

    fprintf('%-20s R2 = %.6f\n', ...
        classNames{j},R2(j));

end

%% ============================================================
% 18. CREATE PERFORMANCE TABLE
% ============================================================

performanceTable = table( ...
    classNames', ...
    rmse, ...
    R2, ...
    'VariableNames', ...
    {'Class','RMSE','R2'});

fprintf('\n============================================================\n');
fprintf('MODEL PERFORMANCE\n');
fprintf('============================================================\n');

disp(performanceTable);

%% ============================================================
% 19. PLOT OBSERVED ANNUAL CHANGES
% ============================================================

figure('Name', ...
    'Observed Annual LULC Change', ...
    'NumberTitle','off');

plot(years(2:end),dX(:,1),'-o','LineWidth',1.5);
hold on;

plot(years(2:end),dX(:,2),'-o','LineWidth',1.5);

plot(years(2:end),dX(:,3),'-o','LineWidth',1.5);

plot(years(2:end),dX(:,4),'-o','LineWidth',1.5);

plot(years(2:end),dX(:,5),'-o','LineWidth',1.5);

xlabel('Year');

ylabel('Annual Change in Proportion');

title('Observed Annual LULC Change');

legend(classNames, ...
    'Location','best');

grid on;

%% ============================================================
% 20. SAVE OBSERVED CHANGE FIGURE
% ============================================================

saveas(gcf, ...
    fullfile(dataFolder, ...
    'Observed_LULC_Change_2017_2025.png'));

%% ============================================================
% 21. PLOT OBSERVED VS PREDICTED DERIVATIVE
% ============================================================

figure('Name', ...
    'Observed vs Predicted DDE Change', ...
    'NumberTitle','off');

for j = 1:nClasses

    subplot(3,2,j);

    plot(years(2:end), ...
        Y(j,:), ...
        '-o','LineWidth',1.5);

    hold on;

    plot(years(2:end), ...
        dX_pred(j,:), ...
        '--s','LineWidth',1.5);

    xlabel('Year');

    ylabel('Change');

    title(classNames{j});

    legend('Observed','DDE Predicted');

    grid on;

end

%% ============================================================
% 22. SAVE COMPARISON FIGURE
% ============================================================

saveas(gcf, ...
    fullfile(dataFolder, ...
    'DDE_Observed_vs_Predicted_2017_2025.png'));

%% ============================================================
% 23. DISPLAY INTERACTION MATRICES
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('INTERPRETATION OF MATRIX A\n');
fprintf('============================================================\n');

fprintf(['Matrix A represents the estimated instantaneous\n' ...
         'interaction between LULC classes.\n\n']);

for i = 1:nClasses

    for j = 1:nClasses

        fprintf('%-20s <- %-20s : %10.6f\n', ...
            classNames{i}, ...
            classNames{j}, ...
            A(i,j));

    end

end

fprintf('\n');
fprintf('============================================================\n');
fprintf('INTERPRETATION OF MATRIX B\n');
fprintf('============================================================\n');

fprintf(['Matrix B represents the estimated delayed interaction\n' ...
         'between LULC classes after %.1f year.\n\n'],tau);

for i = 1:nClasses

    for j = 1:nClasses

        fprintf('%-20s <- %-20s : %10.6f\n', ...
            classNames{i}, ...
            classNames{j}, ...
            B(i,j));

    end

end

%% ============================================================
% 24. SAVE DDE MODEL
% ============================================================

modelFile = fullfile(dataFolder, ...
    'LULC_DDE_Model_2017_2025.mat');

save(modelFile, ...
    'years', ...
    'X', ...
    'tData', ...
    'tau', ...
    'A', ...
    'B', ...
    'C', ...
    'dX', ...
    'dX_pred', ...
    'rmse', ...
    'R2', ...
    'classNames', ...
    'lambda');

fprintf('\nDDE model saved:\n%s\n',modelFile);

%% ============================================================
% 25. SAVE PERFORMANCE CSV
% ============================================================

performanceFile = fullfile(dataFolder, ...
    'LULC_DDE_Performance_2017_2025.csv');

writetable(performanceTable,performanceFile);

fprintf('\nPerformance table saved:\n%s\n', ...
    performanceFile);

%% ============================================================
% 26. FINAL MESSAGE
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('STEP 2 COMPLETED\n');
fprintf('============================================================\n');

fprintf('\nGenerated files:\n');

fprintf('1. LULC_DDE_Model_2017_2025.mat\n');
fprintf('2. LULC_DDE_Performance_2017_2025.csv\n');
fprintf('3. Observed_LULC_Change_2017_2025.png\n');
fprintf('4. DDE_Observed_vs_Predicted_2017_2025.png\n');

fprintf('\nNext stage:\n');
fprintf('STEP 3 = Solve the DDE and simulate future LULC dynamics.\n');

fprintf('\n============================================================\n');