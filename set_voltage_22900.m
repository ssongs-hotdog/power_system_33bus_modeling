%% ============================================================
%% set_voltage_22900.m — 전체 블록 전압 22900V(선간) 일괄 통일
%% IEEE 33-Bus IC-PBL 전력공학 프로젝트 | MATLAB R2024a
%% ============================================================
%% 검증 결과:
%%   세 블록 파라미터 모두 Phase-to-Phase (선간전압, Vrms) 기준
%%   → Incoming1.Voltage         Prompt: "Phase-to-phase voltage (Vrms)"
%%   → Incoming1.BaseVoltage     Prompt: "Base voltage (Vrms ph-ph)"
%%   → BusLoad.NominalVoltage    Prompt: "Nominal phase-to-phase voltage Vn (Vrms)"
%%   → Capacitor.NominalVoltage  Prompt: "Nominal phase-to-phase voltage Vn (Vrms)"
%%   → 모두 동일하게 22900 직접 입력이 맞음
%% ============================================================

%% 0. 환경 초기화
run('setup_env.m');

%% 1. 설정값 (모든 파라미터에 동일하게 적용)
V_LL = 22900;                % 선간전압 [Vrms] — 22.9 kV
V_str = num2str(V_LL);       % 문자열

fprintf('\n========================================\n');
fprintf(' 전압 일괄 설정: 22900 V (선간, Vrms)\n');
fprintf(' 대상: Incoming1 / Bus Load 2~33 / Capacitor 2~33\n');
fprintf('========================================\n\n');

%% 2. 모델 로드
fprintf('[로드] %s\n', simName);
load_system(simName);

%% ============================================================
%% [1] Incoming1 — Three-Phase Source
%%     Voltage    : Phase-to-phase voltage (Vrms) → 22900
%%     BaseVoltage: Base voltage (Vrms ph-ph)     → 22900
%% ============================================================
fprintf('--- [1] Incoming1 소스 블록 ---\n');
incBlk = [simName '/Incoming1'];
try
    old_v  = get_param(incBlk, 'Voltage');
    old_bv = get_param(incBlk, 'BaseVoltage');
    set_param(incBlk, 'Voltage',     V_str);
    set_param(incBlk, 'BaseVoltage', V_str);
    fprintf('  Voltage    : %s → %s V  ✅\n', old_v,  V_str);
    fprintf('  BaseVoltage: %s → %s V  ✅\n', old_bv, V_str);
catch ME
    fprintf('  ❌ 실패: %s\n', ME.message);
end

%% ============================================================
%% [2] Bus_2 ~ Bus_33 : Load 블록 + Capacitor 블록
%%     NominalVoltage: Nominal phase-to-phase voltage Vn (Vrms) → 22900
%% ============================================================
fprintf('\n--- [2] Bus Load 2~33 & Capacitor 2~33 ---\n');

loadOK = 0; loadErr = 0;
capOK  = 0; capErr  = 0;

for i = 2:noBuses
    %% Load 블록 변경
    pmcBlks = find_system([simName sprintf('/Bus_%d', i)], ...
                          'SearchDepth', 1, 'BlockType', 'PMComponent');
    for m = 1:length(pmcBlks)
        bn = get_param(pmcBlks{m}, 'Name');
        % Capacitor는 별도 처리
        if ~isempty(regexp(bn, '^Capacitor', 'once'))
            continue;
        end
        try
            set_param(pmcBlks{m}, 'NominalVoltage', V_str);
            loadOK = loadOK + 1;
        catch ME
            fprintf('  ❌ Bus%d Load 실패: %s\n', i, ME.message);
            loadErr = loadErr + 1;
        end
    end

    %% Capacitor 블록 변경
    capPath = sprintf('%s/Bus_%d/Capacitor %d', simName, i, i);
    try
        set_param(capPath, 'NominalVoltage', V_str);
        capOK = capOK + 1;
    catch ME
        fprintf('  ❌ Bus%d Capacitor 실패: %s\n', i, ME.message);
        capErr = capErr + 1;
    end
end

fprintf('  Bus Load  변경: %d개 ✅  /  실패: %d개\n', loadOK, loadErr);
fprintf('  Capacitor 변경: %d개 ✅  /  실패: %d개\n', capOK,  capErr);

%% ============================================================
%% [3] 검증 — 샘플 확인
%% ============================================================
fprintf('\n--- [3] 변경 결과 검증 ---\n');

% Incoming1
v1  = get_param([simName '/Incoming1'], 'Voltage');
bv1 = get_param([simName '/Incoming1'], 'BaseVoltage');
fprintf('  Incoming1  Voltage     = %s V\n', v1);
fprintf('  Incoming1  BaseVoltage = %s V\n', bv1);

% Bus 2, 18, 33 샘플
for chk = [2, 18, 33]
    pmc = find_system([simName sprintf('/Bus_%d',chk)], ...
                      'SearchDepth',1,'BlockType','PMComponent');
    for m=1:length(pmc)
        bn  = get_param(pmc{m},'Name');
        nvv = get_param(pmc{m},'NominalVoltage');
        fprintf('  Bus%2d [%-15s] NominalVoltage = %s V\n', chk, bn, nvv);
    end
end

%% ============================================================
%% [4] 저장
%% ============================================================
fprintf('\n--- [4] SLX 저장 ---\n');
save_system(simName);
fprintf('  ✅ %s.slx 저장 완료\n', simName);

%% 완료 요약
fprintf('\n========================================\n');
fprintf(' ✅ 전압 22900V 일괄 설정 완료!\n');
fprintf('========================================\n');
fprintf('  Incoming1 Voltage    = 22900 V (선간)\n');
fprintf('  Incoming1 BaseVoltage= 22900 V (선간)\n');
fprintf('  Load  NominalVoltage = 22900 V ×%d개\n', loadOK);
fprintf('  Cap   NominalVoltage = 22900 V ×%d개\n', capOK);
fprintf('  총 %d개 파라미터 변경\n', 2 + loadOK + capOK);
fprintf('========================================\n');
fprintf('[다음] run_baseline.m 실행\n\n');
