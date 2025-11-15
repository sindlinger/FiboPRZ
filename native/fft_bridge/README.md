# FFT Bridge (ALGLIB)

Pequeno wrapper C++ que expõe `FFT_RealForward` a partir do ALGLIB (`fasttransforms.cpp`).

## Como compilar (MetaEditor / Visual Studio)
1. Copie `fft_bridge.cpp` para `MQL5/Include` (ou abra direto no MetaEditor).
2. Abra o arquivo no MetaEditor e pressione **F7**. Certifique-se de que o Visual Studio Build Tools (mesma arquitetura do MetaEditor) esteja instalado.
3. O build gera `MQL5\Libraries\fft_bridge.dll`. O indicador `fiboprz_v3.25.mq5` espera encontrar esse DLL nessa pasta.

Caso prefira compilar via linha de comando, use o script `build_fft_bridge.bat` (veja o exemplo criado automaticamente ao compilar no MetaEditor). Ajuste o caminho do `vcvars64.bat` conforme seu ambiente.
