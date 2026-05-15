%% ============================================================
%% setup_env.m — 프로젝트 환경 초기화 스크립트
%% IEEE 33-Bus IC-PBL 전력공학 프로젝트
%% ★ MATLAB R2024a 기준 (메인 SW)
%% ============================================================
%% 사용법: 작업 시작 전 이 스크립트를 먼저 실행하세요.
%%         >> run('setup_env.m')

%% 1. 프로젝트 경로 설정
projectPath = fileparts(mfilename('fullpath'));
if isempty(projectPath)
    projectPath = pwd;
end
addpath(projectPath);
cd(projectPath);
fprintf('[완료] 작업 디렉토리: %s\n', projectPath);

%% 2. MATLAB R2024a 확인
matlabVer = version('-release');
fprintf('[확인] MATLAB 버전: R%s\n', matlabVer);
if ~strcmp(matlabVer, '2024a')
    warning('[주의] 현재 환경이 R2024a가 아닙니다 (현재: R%s). R2024a 사용을 권장합니다.', matlabVer);
end

%% 3. 필수 툴박스 확인 (R2024a 기준 설치 확인됨)
requiredTBs = {'Simscape Electrical', 'Simscape', 'Simulink', 'Optimization Toolbox'};
v = ver;
installedNames = {v.Name};
fprintf('\n[툴박스 확인]\n');
for k = 1:length(requiredTBs)
    if any(strcmp(installedNames, requiredTBs{k}))
        fprintf('  ✅ %s\n', requiredTBs{k});
    else
        fprintf('  ❌ %s (미설치 — 일부 기능 제한)\n', requiredTBs{k});
    end
end

%% 4. 시스템 기본 상수 (★ 실측 확인된 값 기준)
Vbase_LL_kV = 22.9;                    % 선간 기준전압 [kV]
Vbase_LL    = Vbase_LL_kV * 1e3;       % 선간 기준전압 [V] = 22,900 V
Vbase_LN    = Vbase_LL / sqrt(3);      % 상 기준전압 [V] ≈ 13,220 V
Vnom_actual = Vbase_LL;                % 블록 실측 정격전압 [V] = 22900V (22.9kV 선간전압 일괄 적용 및 측정 기준)
Sbase       = 1e6;                     % 기준 용량 [VA] = 1 MVA
freq        = 60;                      % 주파수 [Hz]
noBuses     = 33;
noBranches  = 32;
noNoP       = 5;

%% 5. 모델명 (★ SLX 내부 실측 확인된 정확한 이름)
simName = 'Power_System_33Bus_Modeling_test';

%% 6. 커패시터 단위 정의
%   ★ 실측 확인: MaskType = 'Three-Phase Series RLC Load'
%   CapacitivePower 파라미터 단위 = VAR (var)
%   → 1 kVAR 설치 시: set_param(..., 'CapacitivePower', '1000')  (1000 VAR)
%   → 1 MVAR 설치 시: set_param(..., 'CapacitivePower', '1e6')   (1,000,000 VAR)
CAP_UNIT = 'VAR';  % 커패시터 단위 메모

%% 7. 비용 함수 (교안 공식) — D 단위: kVAR
%   C(D) = 0.000375*D^2 - 0.304*D + 678  [$]
%   분할: C_split(D,n) = n * C(D/n)
cost_fn       = @(D)   0.000375.*D.^2 - 0.304.*D + 678;
cost_split_fn = @(D,n) n .* cost_fn(D./n);

% 분할 분기점 계산
% n=1 vs n=2: 단일이 유리한 용량 상한
D_break_1to2 = fzero(@(D) cost_fn(D) - cost_split_fn(D,2), 1000);
D_break_2to3 = fzero(@(D) cost_split_fn(D,2) - cost_split_fn(D,3), 2000);
fprintf('\n[비용 함수] C(D) = 0.000375D² - 0.304D + 678 [$/kVAR]\n');
fprintf('  D < %.2f kVAR → 1개 설치 유리\n', D_break_1to2);
fprintf('  D < %.2f kVAR → 2개 분할 유리\n', D_break_2to3);
fprintf('  D ≥ %.2f kVAR → 3개 분할 유리\n', D_break_2to3);

%% 8. 전압 제약 조건
Vmin_pu = 0.90;
Vmax_pu = 1.05;

%% 9. 교안 표준 부하 데이터 [Bus, P(W), Q(var)]
busLoadData = [
     1,       0,       0;
     2,  500e3,  300e3;
     3,  450e3,  200e3;
     4,  600e3,  400e3;
     5,  300e3,  150e3;
     6,  300e3,  100e3;
     7, 1000e3,  500e3;
     8, 1000e3,  500e3;
     9,  300e3,  100e3;
    10,  300e3,  100e3;
    11,  225e3,  150e3;
    12,  300e3,  175e3;
    13,  300e3,  175e3;
    14,  600e3,  400e3;
    15,  300e3,   50e3;
    16,  300e3,  100e3;
    17,  300e3,  100e3;
    18,  450e3,  200e3;
    19,  450e3,  200e3;
    20,  450e3,  200e3;
    21,  450e3,  200e3;
    22,  450e3,  200e3;
    23,  450e3,  250e3;
    24, 2100e3, 1000e3;
    25, 2100e3, 1000e3;
    26,  300e3,  125e3;
    27,  300e3,  125e3;
    28,  300e3,  100e3;
    29,  600e3,  350e3;
    30, 1000e3, 3000e3;
    31,  750e3,  350e3;
    32, 1050e3,  500e3;
    33,  300e3,  200e3;
];

%% 10. 교안 표준 선로 데이터 [From, To, R(Ω), X(Ω)]
branchData = [
     1,  2, 0.0922, 0.0477;
     2,  3, 0.4930, 0.2511;
     3,  4, 0.3660, 0.1864;
     4,  5, 0.3811, 0.1941;
     5,  6, 0.8190, 0.7070;
     6,  7, 0.1872, 0.6188;
     7,  8, 1.7114, 1.2351;
     8,  9, 1.0300, 0.7400;
     9, 10, 1.0400, 0.7400;
    10, 11, 0.1966, 0.0650;
    11, 12, 0.3744, 0.1238;
    12, 13, 1.4680, 1.1550;
    13, 14, 0.5416, 0.7129;
    14, 15, 0.5910, 0.5260;
    15, 16, 0.7463, 0.5450;
    16, 17, 1.2890, 1.7210;
    17, 18, 0.7320, 0.5740;
     2, 19, 0.1640, 0.1565;
    19, 20, 1.5042, 1.3554;
    20, 21, 0.4095, 0.4784;
    21, 22, 0.7089, 0.9373;
     3, 23, 0.4512, 0.3083;
    23, 24, 0.8980, 0.7091;
    24, 25, 0.8960, 0.7011;
     6, 26, 0.2030, 0.1034;
    26, 27, 0.2842, 0.1447;
    27, 28, 1.0590, 0.9337;
    28, 29, 0.8042, 0.7006;
    29, 30, 0.5075, 0.2585;
    30, 31, 0.9744, 0.9630;
    31, 32, 0.3105, 0.3619;
    32, 33, 0.3410, 0.5302;
];

%% 완료 메시지
fprintf('\n========================================\n');
fprintf(' IEEE 33-Bus IC-PBL 프로젝트 (R2024a)\n');
fprintf('========================================\n');
fprintf(' 모델명    : %s\n', simName);
fprintf(' 기준전압  : %.1f kV (LL) / %.2f V (LN)\n', Vbase_LL_kV, Vbase_LN);
fprintf(' 정격전압  : %.2f V (블록 실측값)\n', Vnom_actual);
fprintf(' 주파수    : %d Hz | 캐패시터 단위: %s\n', freq, CAP_UNIT);
fprintf(' 전압 범위 : %.2f ~ %.2f p.u.\n', Vmin_pu, Vmax_pu);
fprintf('========================================\n');
fprintf('[준비완료] run_baseline.m → 베이스라인 분석\n\n');
