clear;
% Параметры
bps = 3;  % Количество бит на символ для 8PSK
EbN0_dB = (0:0.5:10);  % Значения Eb/N0 в дБ
frameLength = 300;  % Длина кадра

% Создание объектов
convEncoder = comm.ConvolutionalEncoder('TrellisStructure', poly2trellis(7, [171 133]), 'TerminationMethod', 'Truncated');  % Создание свёрточного кодера
pskMod = comm.PSKModulator('BitInput', true, 'PhaseOffset', 0, 'ModulationOrder', 8);  % Создание PSK модулятора
appDecoderLLR = comm.APPDecoder('TrellisStructure', poly2trellis(7, [171 133]), 'Algorithm', 'True APP', 'CodedBitLLROutputPort', false);  % Создание декодера APP для Log-likelihood ratio
appDecoderApproxLLR = comm.APPDecoder('TrellisStructure', poly2trellis(7, [171 133]), 'Algorithm', 'True APP', 'CodedBitLLROutputPort', false);  % Создание декодера APP для Approximate log-likelihood ratio
appDecoder8PSK = comm.APPDecoder('TrellisStructure', poly2trellis(7, [171 133]), 'Algorithm', 'True APP', 'CodedBitLLROutputPort', false);  % Создание декодера APP декодера для demap8PSK_Rmatrix

% Инициализация объектов для подсчета ошибок
errorRateLLR = comm.ErrorRate;  % Объект для подсчета ошибок (Log-likelihood ratio)
errorRateApproxLLR = comm.ErrorRate;  % Объект для подсчета ошибок (Approximate log-likelihood ratio)
errorRate8PSK = comm.ErrorRate;  % Объект для подсчета ошибок (demap8PSK_Rmatrix)

% Предварительное выделение массивов BER
berLLR = zeros(1, length(EbN0_dB));  % Вектор для хранения BER (Log-likelihood ratio)
berApproxLLR = zeros(1, length(EbN0_dB));  % Вектор для хранения BER (Approximate log-likelihood ratio)
ber8PSK = zeros(1, length(EbN0_dB));  % Вектор для хранения BER (demap8PSK_Rmatrix)

tic;

for k_idx = 1:length(EbN0_dB)
    rate = 1/2;
    EsNo = EbN0_dB(k_idx) + 10*log10(bps);  % Преобразование Eb/N0 в Es/N0
    snr_dB = EsNo + 10*log10(rate);  % Отношение сигнал/шум в дБ
    noiseVar = 1./(10.^(snr_dB/10));  % Дисперсия шума

    % Инициализация статистики ошибок
    errorStatsLLR = zeros(1, 3);  % Статистика ошибок для Log-likelihood ratio
    errorStatsApproxLLR = zeros(1, 3);  % Статистика ошибок для Approximate log-likelihood ratio
    errorStats8PSK = zeros(1, 3);  % Статистика ошибок для demap8PSK_Rmatrix

    % Цикл для подсчета ошибок
    while errorStatsLLR(2) < 1e5 && errorStatsLLR(3) < 1e8
        % Генерация данных
        data = randi([0 1], frameLength, 1);
        encodedData = convEncoder(data);
        modSignal = pskMod(encodedData);
        awgnChan = comm.AWGNChannel('NoiseMethod', 'Variance', 'Variance', noiseVar);
        receivedSignal = awgnChan(modSignal);

        % Демодуляция с использованием PSKDemodulator Log-likelihood ratio
        pskDemodLLR = comm.PSKDemodulator('BitOutput', true, 'PhaseOffset', pi/8, 'DecisionMethod', 'Log-likelihood ratio', 'Variance', noiseVar);
        demodSignalLLR = pskDemodLLR(receivedSignal);
        receivedSoftBitsLLR = appDecoderLLR(zeros(frameLength, 1), -demodSignalLLR);
        receivedBitsLLR = double(receivedSoftBitsLLR > 0);
        errorStatsLLR = errorRateLLR(data, receivedBitsLLR);

        % Демодуляция с использованием PSKDemodulator Approximate log-likelihood ratio
        pskDemodApproxLLR = comm.PSKDemodulator('BitOutput', true, 'PhaseOffset', pi/8, 'DecisionMethod', 'Approximate log-likelihood ratio', 'Variance', noiseVar);
        demodSignalApproxLLR = pskDemodApproxLLR(receivedSignal);
        receivedSoftBitsApproxLLR = appDecoderApproxLLR(zeros(frameLength, 1), -demodSignalApproxLLR);
        receivedBitsApproxLLR = double(receivedSoftBitsApproxLLR > 0);
        errorStatsApproxLLR = errorRateApproxLLR(data, receivedBitsApproxLLR);

        % Демодуляция с использованием demap8PSK_Rmatrix
        demodSignal8PSK = demap8PSK_Rmatrix(receivedSignal, noiseVar);
        receivedSoftBits8PSK = appDecoder8PSK(zeros(frameLength, 1), demodSignal8PSK);
        receivedBits8PSK = double(receivedSoftBits8PSK > 0);
        errorStats8PSK = errorRate8PSK(data, receivedBits8PSK);
    end

    % Сохранение данных BER и сброс объектов подсчета ошибок
    berLLR(k_idx) = errorStatsLLR(1);  % Сохранение BER для Log-likelihood ratio
    berApproxLLR(k_idx) = errorStatsApproxLLR(1);  % Сохранение BER для Approximate log-likelihood ratio
    ber8PSK(k_idx) = errorStats8PSK(1);  % Сохранение BER для demap8PSK_Rmatrix

    reset(errorRateLLR);  % Сброс объекта подсчета ошибок
    reset(errorRateApproxLLR);  % Сброс объекта подсчета ошибок
    reset(errorRate8PSK);  % Сброс объекта подсчета ошибок

    fprintf('Выполнение: %.2f%%\n', (k_idx / length(EbN0_dB)) * 100);
end

elapsedTime = toc;
fprintf('Время выполнения программы в секундах: %.2f \n', elapsedTime);
fprintf('Время выполнения программы в минутах: %.2f \n', elapsedTime / 60);

% Построение графика BER
figure;
semilogy(EbN0_dB, berLLR, '-o', EbN0_dB, berApproxLLR, '-square', EbN0_dB, ber8PSK, '-diamond');
grid;
xlabel('E_b/N_0 (dB)');  % Подпись оси X
ylabel('Bit Error Rate');  % Подпись оси Y
legend('Log-MAP (LLR)', 'Max-Log-MAP (Approximate LLR)', 'demap8PSK_Rmatrix');

% Функция для демодуляции 8PSK сигнала и вычисления LLR значений
function LLRs = demap8PSK_Rmatrix(sig, sigma2)
LLRs = zeros(1, length(sig)*3);  % Инициализация массива LLR значений

% Проходим по каждому символу и вычисляем LLR значения
for k=0:(length(sig) - 1)
    yI = real(sig(k+1));
    yQ = imag(sig(k+1));

    % Вычисляем фазовый угол принятого символа
    phaseAngle = atan2(yQ, yI);

    % Определяем область на основе фазового угла
    region = determineRegion(phaseAngle);

    % Получаем R-матрицу для определенной области
    R = getRMatrix(region);

    % Вычисляем LLR значения для текущего символа
    LLRs(3*k+1) = yI * (1/sigma2) * R(1,1) + yQ * (1/sigma2) * R(2,1);
    LLRs(3*k+2) = yI * (1/sigma2) * R(1,2) + yQ * (1/sigma2) * R(2,2);
    LLRs(3*k+3) = yI * (1/sigma2) * R(1,3) + yQ * (1/sigma2) * R(2,3);
end

LLRs = reshape(LLRs, [], 1);  % Преобразование массива LLR значений в вектор
end

% Функция для определения области фазового угла
function region = determineRegion(phaseAngle)
% Нормализация угла фазы в диапазон [-pi, pi)
phaseAngle = mod(phaseAngle + pi, 2*pi) - pi;

% Определение границ для всех восьми областей
region_bounds = [-pi, -3*pi/4, -pi/2, -pi/4, 0, pi/4, pi/2, 3*pi/4];

% Определение области фазового угла
region = find(phaseAngle >= region_bounds, 1, 'last');
if isempty(region)
    region = 1;
end
end

% Функция для получения R-матрицы для определенной области
function R = getRMatrix(region)
angles_b0 = [
    -7*pi/8, 7*pi/8;  % область i
    -5*pi/8, 7*pi/8;  % область ii
    -3*pi/8, pi/8;    % область iii
    -pi/8,   pi/8;    % область iv
    -pi/8,   pi/8;    % область v
    -pi/8,   3*pi/8;  % область vi
    -7*pi/8, 5*pi/8;  % область vii
    -7*pi/8, 7*pi/8   % область viii
    ];

phi_1_b0 = angles_b0(region, 1);
phi_0_b0 = angles_b0(region, 2);

cos_diff_b0 = cos(phi_1_b0) - cos(phi_0_b0);
sin_diff_b0 = sin(phi_1_b0) - sin(phi_0_b0);

angles_b1 = [
    -7*pi/8, -3*pi/8; % область i
    -5*pi/8, -3*pi/8; % область ii
    -5*pi/8, -3*pi/8; % область iii
    -5*pi/8, -pi/8;   % область iv
    5*pi/8, pi/8;     % область v
    5*pi/8, 3*pi/8;   % область vi
    5*pi/8, 3*pi/8;   % область vii
    7*pi/8, 3*pi/8;   % область viii
    ];

phi_1_b1 = angles_b1(region, 1);
phi_0_b1 = angles_b1(region, 2);

cos_diff_b1 = cos(phi_1_b1) - cos(phi_0_b1);
sin_diff_b1 = sin(phi_1_b1) - sin(phi_0_b1);

angles_b2 = [
    -5*pi/8, -7*pi/8; % область i
    -5*pi/8, -7*pi/8; % область ii
    -3*pi/8, -pi/8;   % область iii
    -3*pi/8, -pi/8;   % область iv
    3*pi/8,  pi/8;    % область v
    3*pi/8,  pi/8;    % область vi
    5*pi/8,  7*pi/8;  % область vii
    5*pi/8,  7*pi/8;  % область viii
    ];

phi_1_b2 = angles_b2(region, 1);
phi_0_b2 = angles_b2(region, 2);

cos_diff_b2 = cos(phi_1_b2) - cos(phi_0_b2);
sin_diff_b2 = sin(phi_1_b2) - sin(phi_0_b2);

R = [
    cos_diff_b0, cos_diff_b1, cos_diff_b2;
    sin_diff_b0, sin_diff_b1, sin_diff_b2;
    ];
end
