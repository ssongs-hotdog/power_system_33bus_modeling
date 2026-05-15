%% =======================================================
%% ⚡ 사용자 입력란 (이곳의 숫자만 자유롭게 바꾸세요!) ⚡
%% =======================================================
% 1번부터 33번 버스까지 들어갈 커패시터 용량(Q, 단위: VAR)을 
% 아래 배열 안에 쉼표로 구분하여 직접 적어주시면 됩니다.
% (※ 1번 버스는 Slack이므로 항상 0으로 두세요)

Qc_values = [ ...
    0,   1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, ... % 1번 ~ 10번
    1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, ... % 11번 ~ 20번
    1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, ... % 21번 ~ 30번
    1000, 1000, 1000 ...                                     % 31번 ~ 33번
];

%% =======================================================
%% 이하 코드는 건드릴 필요 없이 자동으로 실행됩니다.
%% =======================================================

% Created by JY Wong, 26 October 2019
% MATLAB program for Simulink model of the IEEE 33 bus system 

%% General information of the system
noBranches = 32;                
noNoP = 5;                      
noBuses = 33;                   
noMeaurements = noBranches;     

%% Initialization of the circuit breaker input vector
timeTS = (0:0.001:0.2)';        
CBStats = [ones(length(timeTS),noBranches),zeros(length(timeTS),noNoP)];
siminCB = timeseries(CBStats,timeTS);

%% Simulink 모델에 영구 반영 및 저장
simName = 'Power_System_33Bus_Modeling_test'; 
load_system(simName); % 모델을 백그라운드에서 엽니다

for i = 2:noBuses
    blockPath = sprintf('%s/Bus_%d/Capacitor %d', simName, i, i);
    try
        % 파일 원본의 값을 직접 수정
        set_param(blockPath, 'CapacitivePower', num2str(Qc_values(i)));
    catch ME
        fprintf('%d번 버스 업데이트 에러: %s\n', i, ME.message);
    end
end

% 수정된 내용을 .slx 파일에 영구 저장
save_system(simName);
fprintf('>> [완료] 입력하신 커패시터 값이 %s 모델에 영구 저장되었습니다!\n', simName);

%% Simulation phase
simIn = Simulink.SimulationInput(simName);
simIn = simIn.setVariable('siminCB', siminCB);

% Run simulation
disp('>> [진행중] 시뮬레이션을 돌리고 있습니다. 잠시만 기다려주세요...');
simout = sim(simIn);

% --- 결과 데이터 추출 ---
ISimMat = simout.simOutputI.data;
VSimMat = simout.simOutputV.data;

IRMSMat = zeros(size(ISimMat,1), size(ISimMat,2)/3);
for iterS = 1:size(ISimMat,2)/3
    IRMSMat(:,iterS) = mean(ISimMat(:,(iterS-1)*3+1:(iterS-1)*3+3),2);
end

VRMSMat = zeros(size(VSimMat,1), size(VSimMat,2)/3);
for iterS = 1:size(VSimMat,2)/3
    VRMSMat(:,iterS) = mean(VSimMat(:,(iterS-1)*3+1:(iterS-1)*3+3),2);
end

disp('>> [성공] 시뮬레이션 완료 및 전압/전류 데이터(VRMSMat, IRMSMat) 추출 성공!');