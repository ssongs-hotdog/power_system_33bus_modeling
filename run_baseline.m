%% ============================================================
%% run_baseline.m — 베이스라인 시뮬레이션 (커패시터 미설치)
%% IEEE 33-Bus IC-PBL 전력공학 프로젝트 | MATLAB R2024a
%% ============================================================
%% 목적: 모든 커패시터 = 0 VAR → 시뮬레이션 → Bus별 전압 p.u. 측정
%% 결과: V_pu (33×1), VRMSMat, IRMSMat 변수 생성 + 그래프 출력
%% 실행: setup_env.m 먼저 실행 후 이 파일 실행
%% ============================================================

%% 0. 환경 초기화
run('setup_env.m');

%% 1. 커패시터 전체 0 설정 (베이스라인)
Qc_values = zeros(1, noBuses);  % 1×33, 모두 0 VAR
fprintf('[설정] 베이스라인: 모든 버스 커패시터 = 0 VAR\n');

%% 2. 차단기 입력 벡터
timeTS  = (0:0.001:0.2)';
CBStats = [ones(length(timeTS), noBranches), zeros(length(timeTS), noNoP)];
siminCB = timeseries(CBStats, timeTS);

%% 3. 모델 로드 및 커패시터 파라미터 설정
fprintf('[로드] 모델 로딩 중: %s\n', simName);
load_system(simName);

errCount = 0;
for i = 2:noBuses
    blockPath = sprintf('%s/Bus_%d/Capacitor %d', simName, i, i);
    try
        val = Qc_values(i);
        if val == 0
            val = 1e-6; % Simulink 에러 방지 (P, QL, QC 중 하나는 0이 아니어야 함)
        end
        set_param(blockPath, 'CapacitivePower', num2str(val));
    catch ME
        fprintf('  ⚠ Bus %d 설정 실패: %s\n', i, ME.message);
        errCount = errCount + 1;
    end
end
fprintf('[완료] 커패시터 설정 (에러: %d개)\n', errCount);

%% 4. 시뮬레이션 실행
fprintf('[시뮬] 베이스라인 시뮬레이션 실행 중 (약 30초~1분)...\n');
simIn = Simulink.SimulationInput(simName);
simIn = simIn.setVariable('siminCB', siminCB);
simout = sim(simIn);
fprintf('[완료] 시뮬레이션 완료!\n');

%% 5. 전압 데이터 추출
VSimMat = simout.simOutputV.data;  % [시간 × (버스수×3)]
ISimMat = simout.simOutputI.data;  % [시간 × (브랜치수×3)]

nV = size(VSimMat, 2) / 3;
nI = size(ISimMat, 2) / 3;

VRMSMat = zeros(size(VSimMat,1), nV);
IRMSMat = zeros(size(ISimMat,1), nI);

for k = 1:nV
    VRMSMat(:,k) = mean(abs(VSimMat(:, (k-1)*3+1 : k*3)), 2);
end
for k = 1:nI
    IRMSMat(:,k) = mean(abs(ISimMat(:, (k-1)*3+1 : k*3)), 2);
end

%% 6. 정상상태 추출 및 p.u. 변환
% 마지막 20% 구간 평균 (정상상태 수렴 확인)
steadyIdx = round(0.8*size(VRMSMat,1)) : size(VRMSMat,1);
V_branch_steady = mean(VRMSMat(steadyIdx, :), 1);  % [V] (Branch 순서, 1x32)
V_branch_pu = V_branch_steady / Vnom_actual;       % p.u. (Branch 순서, 1x32)

% 실제 Bus 번호로 매핑 (1번 모선은 Slack = 1.0 p.u.)
toBus = [2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33];
V_bus_pu = ones(1, 33);
V_bus_pu(toBus) = V_branch_pu;

V_bus_V = 22900 * ones(1, 33);
V_bus_V(toBus) = V_branch_steady;

%% 7. 결과 테이블 출력
fprintf('\n============================================================\n');
fprintf('  베이스라인 Bus 전압 프로파일 (커패시터 미설치, R2024a)\n');
fprintf('============================================================\n');
fprintf('  Bus | V [V]     | V [p.u.] | 상태\n');
fprintf('  ----|-----------|----------|---------------------------\n');

violationBuses = [];
for i = 1:noBuses
    if V_bus_pu(i) < Vmin_pu
        status = '❌ 저전압 위반';
        violationBuses(end+1) = i;
    elseif V_bus_pu(i) > Vmax_pu
        status = '❌ 과전압 위반';
        violationBuses(end+1) = i;
    else
        status = '✅ 정상';
    end
    fprintf('   %2d | %9.2f | %.6f | %s\n', i, V_bus_V(i), V_bus_pu(i), status);
end

[minV, minBus] = min(V_bus_pu);
[maxV, maxBus] = max(V_bus_pu);

fprintf('\n[요약]\n');
fprintf('  최저 전압: Bus %2d = %.6f p.u.  (%.2f V)\n', minBus, minV, V_bus_V(minBus));
fprintf('  최고 전압: Bus %2d = %.6f p.u.  (%.2f V)\n', maxBus, maxV, V_bus_V(maxBus));
fprintf('  전압 위반 Bus 수: %d개\n', length(violationBuses));
if ~isempty(violationBuses)
    fprintf('  위반 Bus: '); fprintf('%d ', violationBuses); fprintf('\n');
end
fprintf('============================================================\n');

%% 8. 그래프 생성
figure('Name','[베이스라인] IEEE 33-Bus 전압 프로파일','NumberTitle','off',...
       'Position',[100 100 1000 480], 'Color','white');

b = bar(1:noBuses, V_bus_pu, 'FaceColor','flat');
for k = 1:noBuses
    if V_bus_pu(k) < Vmin_pu
        b.CData(k,:) = [0.9 0.2 0.2];   % 빨강: 저전압
    elseif V_bus_pu(k) > Vmax_pu
        b.CData(k,:) = [0.9 0.6 0.1];   % 주황: 과전압
    else
        b.CData(k,:) = [0.2 0.5 0.85];  % 파랑: 정상
    end
end
hold on;
yline(Vmin_pu,'r--','LineWidth',2,'Label','하한 0.90 p.u.');
yline(Vmax_pu,'g--','LineWidth',2,'Label','상한 1.05 p.u.');
hold off;

xlabel('Bus 번호','FontSize',12,'FontWeight','bold');
ylabel('전압 [p.u.]','FontSize',12,'FontWeight','bold');
title('IEEE 33-Bus 베이스라인 전압 프로파일 (커패시터 미설치)','FontSize',13,'FontWeight','bold');
xlim([0 34]); ylim([0.80 1.10]);
xticks(1:33);  grid on;
legend({'버스 전압 (빨강=위반, 파랑=정상)','하한 0.90 p.u.','상한 1.05 p.u.'},'Location','southwest');

% 최저 전압 표시
text(minBus, minV-0.015, sprintf('Bus%d\n%.4f',minBus,minV),...
    'HorizontalAlignment','center','FontSize',9,'Color','red','FontWeight','bold');

fprintf('\n[완료] 베이스라인 분석 완료! 그래프 생성됨.\n');
fprintf('[저장] V_bus_pu, VRMSMat, IRMSMat 변수가 Workspace에 저장됨.\n\n');

% 결과 저장
save('baseline_result.mat', 'V_bus_pu', 'V_bus_V', 'VRMSMat', 'IRMSMat', 'Qc_values');
fprintf('[저장] baseline_result.mat 파일 저장 완료.\n');
