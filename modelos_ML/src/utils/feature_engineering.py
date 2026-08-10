import numpy as np
import pandas as pd

def build_lottery_features(matrix, df_dates, max_white_ball, t_idx, target_ball):
    """
    Construye el conjunto de características (features) estadísticas avanzadas
    para una balota específica (target_ball) hasta la posición t_idx.
    
    Parámetros:
    - matrix: numpy array 2D de forma (total_draws, max_white_ball + 1) con 0 y 1.
    - df_dates: pandas Series con las fechas de los sorteos.
    - max_white_ball: Número máximo de balotas blancas en la lotería.
    - t_idx: Índice del punto histórico a evaluar (e.g. número total de sorteos).
    - target_ball: El número de balota (1 a max_white_ball) a analizar.
    
    Retorna:
    - X_train: DataFrame de Pandas con los predictores históricos.
    - y_train: numpy array con las etiquetas (0 ó 1) en cada sorteo histórico.
    - X_test: DataFrame de 1 fila con las características para el próximo sorteo a predecir.
    """
    col = matrix[:t_idx, target_ball]
    max_k = t_idx
    
    # 1. Cumsum incremental para frecuencias móviles
    cumsum = np.zeros(max_k + 1, dtype=np.int32)
    cumsum[1:] = np.cumsum(col)
    
    # 2. Decay exponencial incremental
    alpha = np.exp(-0.03)
    decay_arr = np.zeros(max_k + 1)
    for i in range(max_k):
        decay_arr[i + 1] = alpha * decay_arr[i] + col[i]
        
    # 3. Reciencia (sorteos transcurridos desde última aparición)
    last_seen = np.full(max_k + 1, -1, dtype=np.int32)
    for i in range(max_k):
        last_seen[i + 1] = i if col[i] == 1 else last_seen[i]
    indices = np.arange(max_k + 1)
    recency_full = np.where(last_seen >= 0, indices - last_seen, 100)

    # 4. Cálculo de Gaps / Atrasos Históricos y Z-Score de Atraso
    appearances = np.where(col == 1)[0]
    if len(appearances) > 1:
        gaps = np.diff(appearances)
        mean_gap = float(np.mean(gaps))
        std_gap = float(np.std(gaps)) if np.std(gaps) > 0 else 1.0
    else:
        mean_gap = 10.0
        std_gap = 5.0
        
    zscore_atraso_full = (recency_full - mean_gap) / (std_gap + 1e-5)

    # Definir rango de entrenamiento (hasta los últimos 500 sorteos)
    start_k = max(0, max_k - 500)
    k_range = np.arange(start_k + 50, max_k)
    
    if len(k_range) == 0:
        return pd.DataFrame(), np.array([]), pd.DataFrame()

    f5   = cumsum[k_range] - cumsum[np.maximum(0, k_range - 5)]
    f10  = cumsum[k_range] - cumsum[np.maximum(0, k_range - 10)]
    f20  = cumsum[k_range] - cumsum[np.maximum(0, k_range - 20)]
    f50  = cumsum[k_range] - cumsum[np.maximum(0, k_range - 50)]
    f100 = cumsum[k_range] - cumsum[np.maximum(0, k_range - 100)]
    
    fechas = pd.to_datetime(df_dates.iloc[k_range])
    
    # Propiedades estructurales del número
    is_even = 1 if (target_ball % 2 == 0) else 0
    is_high = 1 if (target_ball > max_white_ball // 2) else 0
    last_digit = target_ball % 10

    X_train = pd.DataFrame({
        'recency'        : recency_full[k_range],
        'zscore_atraso'  : zscore_atraso_full[k_range],
        'f5'             : f5,
        'f10'            : f10,
        'f20'            : f20,
        'f50'            : f50,
        'f100'           : f100,
        'decay'          : decay_arr[k_range],
        'year'           : fechas.dt.year.values,
        'month'          : fechas.dt.month.values,
        'day'            : fechas.dt.day.values,
        'dayofweek'      : fechas.dt.dayofweek.values,
        'is_even'        : is_even,
        'is_high'        : is_high,
        'last_digit'     : last_digit,
    })
    
    y_train = col[k_range]

    # --- Construcción de Vector X_test para la predicción actual ---
    t_dt = pd.to_datetime(df_dates.max())
    recency_t = recency_full[t_idx]
    zscore_t = zscore_atraso_full[t_idx]
    decay_t = decay_arr[t_idx]
    
    f5_t   = int(cumsum[t_idx] - cumsum[max(0, t_idx - 5)])
    f10_t  = int(cumsum[t_idx] - cumsum[max(0, t_idx - 10)])
    f20_t  = int(cumsum[t_idx] - cumsum[max(0, t_idx - 20)])
    f50_t  = int(cumsum[t_idx] - cumsum[max(0, t_idx - 50)])
    f100_t = int(cumsum[t_idx] - cumsum[max(0, t_idx - 100)])

    X_test = pd.DataFrame([{
        'recency'        : recency_t,
        'zscore_atraso'  : zscore_t,
        'f5'             : f5_t,
        'f10'            : f10_t,
        'f20'            : f20_t,
        'f50'            : f50_t,
        'f100'           : f100_t,
        'decay'          : decay_t,
        'year'           : t_dt.year,
        'month'          : t_dt.month,
        'day'            : t_dt.day,
        'dayofweek'      : t_dt.dayofweek,
        'is_even'        : is_even,
        'is_high'        : is_high,
        'last_digit'     : last_digit,
    }])

    return X_train, y_train, X_test
