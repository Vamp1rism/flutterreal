import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const FocusNotesProApp());
}

class FocusNotesProApp extends StatelessWidget {
  const FocusNotesProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Notes Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const FocusNotesProHome(),
    );
  }
}

enum SessionPhase { study, breakTime }

enum GameDifficulty {
  easy('Fácil'),
  medium('Médio'),
  hard('Difícil');

  final String label;
  const GameDifficulty(this.label);
}

enum BreakGameType {
  reflex('Reflexo'),
  pong('Pong'),
  tetris('Tetris');

  final String label;
  const BreakGameType(this.label);
}

enum PongMaxSpeedPreset {
  slow('Máx: Lenta', 0.012),
  medium('Máx: Média', 0.018),
  fast('Máx: Rápida', 0.025),
  turbo('Máx: Turbo', 0.033);

  final String label;
  final double maxSpeed;
  const PongMaxSpeedPreset(this.label, this.maxSpeed);
}

class StudyTopic {
  final String id;
  String title;
  String notes;
  bool isCompleted;

  StudyTopic({
    required this.id,
    required this.title,
    this.notes = '',
    this.isCompleted = false,
  });
}

class _PongFrameState {
  final double ballX;
  final double ballY;
  final double playerPaddleX;
  final double cpuPaddleX;
  final int playerScore;
  final int cpuScore;
  final double currentSpeedFactor;
  final int tick;

  const _PongFrameState({
    required this.ballX,
    required this.ballY,
    required this.playerPaddleX,
    required this.cpuPaddleX,
    required this.playerScore,
    required this.cpuScore,
    required this.currentSpeedFactor,
    required this.tick,
  });
}

class _TetrisFrameState {
  final List<List<int>> board;
  final List<List<int>> activeShape;
  final int activeRow;
  final int activeCol;
  final int ghostRow;
  final int colorIndex;
  final int score;
  final int bestScore;
  final int linesCleared;
  final bool gameOver;
  final int tick;

  const _TetrisFrameState({
    required this.board,
    required this.activeShape,
    required this.activeRow,
    required this.activeCol,
    required this.ghostRow,
    required this.colorIndex,
    required this.score,
    required this.bestScore,
    required this.linesCleared,
    required this.gameOver,
    required this.tick,
  });
}

class FocusNotesProHome extends StatefulWidget {
  const FocusNotesProHome({super.key});

  @override
  State<FocusNotesProHome> createState() => _FocusNotesProHomeState();
}

class _FocusNotesProHomeState extends State<FocusNotesProHome> {
  static const int _tetrisRows = 16;
  static const int _tetrisCols = 10;
  static const List<Color> _tetrisPalette = [
    Colors.transparent,
    Colors.cyanAccent,
    Colors.amberAccent,
    Colors.purpleAccent,
    Colors.greenAccent,
    Colors.redAccent,
    Colors.orangeAccent,
    Colors.lightBlueAccent,
  ];

  static const List<List<List<int>>> _tetrominoShapes = [
    [
      [1, 1, 1, 1],
    ],
    [
      [1, 1],
      [1, 1],
    ],
    [
      [0, 1, 0],
      [1, 1, 1],
    ],
    [
      [1, 0, 0],
      [1, 1, 1],
    ],
    [
      [0, 0, 1],
      [1, 1, 1],
    ],
    [
      [0, 1, 1],
      [1, 1, 0],
    ],
    [
      [1, 1, 0],
      [0, 1, 1],
    ],
  ];

  int _studyMinutes = 25;
  int _breakMinutes = 5;

  SessionPhase _phase = SessionPhase.study;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  int _totalStudiedSeconds = 0;
  Timer? _timer;

  double _timerAreaHeight = 290;
  double _gameAreaHeight = 460;
  double _notesAreaExtent = 540;

  final List<StudyTopic> _topics = [
    StudyTopic(
      id: '1',
      title: 'Revisão Geral',
      notes:
          '- Escreva seus tópicos aqui.\n- No intervalo, o jogo abre maior e pausado com botão Começar.\n- No Tetris: ←/→ ou A/D movem, ↑ ou W giram, ↓ ou S descem, Espaço faz queda direta.',
    ),
  ];
  String? _selectedTopicId = '1';
  final TextEditingController _newTopicController = TextEditingController();
  final TextEditingController _noteEditorController = TextEditingController();
  final TextEditingController _topicTitleController = TextEditingController();

  final FocusNode _arcadeFocusNode = FocusNode(debugLabel: 'ArcadeFocus');

  BreakGameType _selectedGame = BreakGameType.tetris;
  GameDifficulty _difficulty = GameDifficulty.medium;
  bool _isGamePaused = true;
  bool _hasGameStarted = false;

  int _reflexScore = 0;
  int _reflexBestScore = 0;
  double _targetX = 0.5;
  double _targetY = 0.5;
  Timer? _reflexAutoMoveTimer;
  final Random _random = Random();

  PongMaxSpeedPreset _pongMaxSpeedPreset = PongMaxSpeedPreset.fast;
  late final ValueNotifier<_PongFrameState> _pongNotifier;
  double _ballX = 0.5;
  double _ballY = 0.5;
  double _ballVx = 0.006;
  double _ballVy = 0.008;
  double _pongCurrentSpeed = 0.008;
  double _playerPaddleX = 0.5;
  double _cpuPaddleX = 0.5;
  int _pongPlayerScore = 0;
  int _pongCpuScore = 0;
  int _pongTick = 0;
  Timer? _pongLoopTimer;

  late final ValueNotifier<_TetrisFrameState> _tetrisNotifier;
  List<List<int>> _tetrisBoard = _createEmptyTetrisBoard();
  List<List<int>> _activePiece = [
    [1, 1, 1, 1],
  ];
  int _activeRow = 0;
  int _activeCol = 3;
  int _activeColorIndex = 1;
  int _tetrisScore = 0;
  int _tetrisBestScore = 0;
  int _tetrisLinesCleared = 0;
  bool _tetrisGameOver = false;
  int _tetrisTick = 0;
  Timer? _tetrisDropTimer;

  @override
  void initState() {
    super.initState();
    _pongCurrentSpeed = _pongInitialSpeed;
    _pongNotifier = ValueNotifier(
      const _PongFrameState(
        ballX: 0.5,
        ballY: 0.5,
        playerPaddleX: 0.5,
        cpuPaddleX: 0.5,
        playerScore: 0,
        cpuScore: 0,
        currentSpeedFactor: 0.35,
        tick: 0,
      ),
    );
    _tetrisNotifier = ValueNotifier(
      _TetrisFrameState(
        board: _cloneMatrix(_tetrisBoard),
        activeShape: _cloneMatrix(_activePiece),
        activeRow: _activeRow,
        activeCol: _activeCol,
        ghostRow: _computeGhostRow(_activePiece, _activeRow, _activeCol),
        colorIndex: _activeColorIndex,
        score: _tetrisScore,
        bestScore: _tetrisBestScore,
        linesCleared: _tetrisLinesCleared,
        gameOver: _tetrisGameOver,
        tick: 0,
      ),
    );
    _syncControllersWithSelectedTopic();
  }

  static List<List<int>> _createEmptyTetrisBoard() => List.generate(
        _tetrisRows,
        (_) => List.filled(_tetrisCols, 0),
      );

  static List<List<int>> _cloneMatrix(List<List<int>> src) =>
      src.map((row) => List<int>.from(row)).toList();

  int get _currentPhaseTotalSeconds =>
      max(1, (_phase == SessionPhase.study ? _studyMinutes : _breakMinutes) * 60);

  StudyTopic? get _selectedTopic {
    if (_selectedTopicId == null) return null;
    for (final t in _topics) {
      if (t.id == _selectedTopicId) return t;
    }
    return null;
  }

  void _setControllerTextSafely(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _syncControllersWithSelectedTopic() {
    final topic = _selectedTopic;
    _setControllerTextSafely(_topicTitleController, topic?.title ?? '');
    _setControllerTextSafely(_noteEditorController, topic?.notes ?? '');
  }

  void _dragTimerHeight(double dy) {
    setState(() {
      _timerAreaHeight = (_timerAreaHeight + dy).clamp(215.0, 520.0).toDouble();
    });
  }

  void _dragGameHeight(double dy) {
    setState(() {
      _gameAreaHeight = (_gameAreaHeight + dy).clamp(300.0, 700.0).toDouble();
    });
  }

  void _dragNotesExtent(double delta) {
    setState(() {
      _notesAreaExtent = (_notesAreaExtent + delta).clamp(300.0, 950.0).toDouble();
    });
  }

  void _resetAreasSize() {
    setState(() {
      _timerAreaHeight = 290;
      _gameAreaHeight = _phase == SessionPhase.breakTime ? 460 : 350;
      _notesAreaExtent = 540;
    });
  }

  void _togglePlayPause() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
      return;
    }

    setState(() => _isRunning = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          if (_phase == SessionPhase.study) {
            _totalStudiedSeconds++;
          }
        });
      } else {
        _advancePhase();
      }
    });
  }

  void _seekToElapsedSeconds(int newElapsedSeconds) {
    final total = _currentPhaseTotalSeconds;
    final clampedElapsed = newElapsedSeconds.clamp(0, total).toInt();
    final currentElapsed = total - _remainingSeconds;
    final delta = clampedElapsed - currentElapsed;

    setState(() {
      if (_phase == SessionPhase.study && delta > 0) {
        _totalStudiedSeconds += delta;
      }
      _remainingSeconds = total - clampedElapsed;
    });

    if (_remainingSeconds == 0) {
      _advancePhase();
    }
  }

  void _jumpSeconds(int deltaSeconds) {
    final total = _currentPhaseTotalSeconds;
    final currentElapsed = total - _remainingSeconds;
    _seekToElapsedSeconds(currentElapsed + deltaSeconds);
  }

  void _rewindOrRestartPhase() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      final elapsed = _currentPhaseTotalSeconds - _remainingSeconds;
      if (elapsed > 5) {
        _remainingSeconds = _currentPhaseTotalSeconds;
      } else {
        _phase = _phase == SessionPhase.study
            ? SessionPhase.breakTime
            : SessionPhase.study;
        _remainingSeconds = _currentPhaseTotalSeconds;
        _onEnterOrLeaveBreak();
      }
    });
  }

  void _advancePhase() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _phase = _phase == SessionPhase.study
          ? SessionPhase.breakTime
          : SessionPhase.study;
      _remainingSeconds = _currentPhaseTotalSeconds;
      _onEnterOrLeaveBreak();
    });
  }

  void _onEnterOrLeaveBreak() {
    _stopAllGames();
    _isGamePaused = true;
    _hasGameStarted = false;
    if (_phase == SessionPhase.breakTime) {
      if (_gameAreaHeight < 460) {
        _gameAreaHeight = 460;
      }
      _prepareCurrentGame(resetScore: true);
    }
  }

  void _openDurationDialog() {
    int tempStudy = _studyMinutes;
    int tempBreak = _breakMinutes;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tempos de Estudo e Intervalo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DurationStepper(
                label: 'Estudo',
                value: tempStudy,
                min: 1,
                max: 180,
                step: 5,
                onChanged: (v) => setDialogState(() => tempStudy = v),
              ),
              const SizedBox(height: 14),
              _DurationStepper(
                label: 'Intervalo',
                value: tempBreak,
                min: 1,
                max: 60,
                step: 1,
                onChanged: (v) => setDialogState(() => tempBreak = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                _timer?.cancel();
                setState(() {
                  _studyMinutes = tempStudy;
                  _breakMinutes = tempBreak;
                  _isRunning = false;
                  _remainingSeconds = _currentPhaseTotalSeconds;
                });
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _stopAllGames() {
    _reflexAutoMoveTimer?.cancel();
    _pongLoopTimer?.cancel();
    _tetrisDropTimer?.cancel();
  }

  void _prepareCurrentGame({required bool resetScore}) {
    _stopAllGames();
    switch (_selectedGame) {
      case BreakGameType.reflex:
        _setupReflexGame(resetScore: resetScore);
      case BreakGameType.pong:
        _setupPongGame(resetScore: resetScore);
      case BreakGameType.tetris:
        _setupTetrisGame(resetScore: resetScore);
    }
  }

  void _requestArcadeFocusIfAppropriate() {
    if (_phase == SessionPhase.breakTime && !_isGamePaused && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_arcadeFocusNode.hasFocus) {
          _arcadeFocusNode.requestFocus();
        }
      });
    }
  }

  void _startOrToggleGamePause() {
    if (!_hasGameStarted) {
      setState(() {
        _hasGameStarted = true;
        _isGamePaused = false;
      });
      if (_selectedGame == BreakGameType.tetris && _tetrisGameOver) {
        _setupTetrisGame(resetScore: true);
      }
      _requestArcadeFocusIfAppropriate();
      return;
    }
    setState(() => _isGamePaused = !_isGamePaused);
    _requestArcadeFocusIfAppropriate();
  }

  void _restartCurrentGame() {
    setState(() {
      _hasGameStarted = true;
      _isGamePaused = false;
    });
    _prepareCurrentGame(resetScore: true);
    _requestArcadeFocusIfAppropriate();
  }

  void _onSelectGame(BreakGameType game) {
    setState(() {
      _selectedGame = game;
      _isGamePaused = true;
      _hasGameStarted = false;
    });
    _prepareCurrentGame(resetScore: true);
  }

  void _onChangeDifficulty(GameDifficulty diff) {
    setState(() => _difficulty = diff);
    if (_selectedGame == BreakGameType.reflex) {
      _setupReflexGame(resetScore: false);
    } else if (_selectedGame == BreakGameType.tetris) {
      _restartTetrisDropTimer();
    } else if (_selectedGame == BreakGameType.pong) {
      _setPlayerPaddleFromNormalizedX(_playerPaddleX);
    }
  }

  double get _reflexButtonSize {
    switch (_difficulty) {
      case GameDifficulty.easy:
        return 58.0;
      case GameDifficulty.medium:
        return 46.0;
      case GameDifficulty.hard:
        return 36.0;
    }
  }

  int get _reflexPointsPerHit {
    switch (_difficulty) {
      case GameDifficulty.easy:
        return 1;
      case GameDifficulty.medium:
        return 2;
      case GameDifficulty.hard:
        return 3;
    }
  }

  void _setupReflexGame({required bool resetScore}) {
    _reflexAutoMoveTimer?.cancel();
    if (resetScore) _reflexScore = 0;
    _moveReflexTarget();

    final autoMoveMs = switch (_difficulty) {
      GameDifficulty.easy => null,
      GameDifficulty.medium => 1400,
      GameDifficulty.hard => 800,
    };

    if (autoMoveMs != null) {
      _reflexAutoMoveTimer = Timer.periodic(
        Duration(milliseconds: autoMoveMs),
        (_) {
          if (!mounted ||
              _phase != SessionPhase.breakTime ||
              _selectedGame != BreakGameType.reflex ||
              _isGamePaused) {
            return;
          }
          setState(_moveReflexTarget);
        },
      );
    }
  }

  void _moveReflexTarget() {
    _targetX = 0.08 + _random.nextDouble() * 0.84;
    _targetY = 0.10 + _random.nextDouble() * 0.80;
  }

  void _onReflexTargetTap() {
    if (_isGamePaused || !_hasGameStarted) return;
    setState(() {
      _reflexScore += _reflexPointsPerHit;
      if (_reflexScore > _reflexBestScore) {
        _reflexBestScore = _reflexScore;
      }
      _moveReflexTarget();
    });
  }

  double get _pongPaddleWidthFraction {
    switch (_difficulty) {
      case GameDifficulty.easy:
        return 0.34;
      case GameDifficulty.medium:
        return 0.25;
      case GameDifficulty.hard:
        return 0.18;
    }
  }

  double get _pongInitialSpeed => _pongMaxSpeedPreset.maxSpeed * 0.35;

  double get _pongCpuSpeed => (_pongCurrentSpeed * 0.85)
      .clamp(0.005, _pongMaxSpeedPreset.maxSpeed * 0.92)
      .toDouble();

  void _setBallDirectionSpeed(double newSpeed) {
    final clamped =
        newSpeed.clamp(_pongInitialSpeed, _pongMaxSpeedPreset.maxSpeed).toDouble();
    _pongCurrentSpeed = clamped;
    final currentMag = sqrt(_ballVx * _ballVx + _ballVy * _ballVy);
    if (currentMag > 0.00001) {
      _ballVx = (_ballVx / currentMag) * clamped;
      _ballVy = (_ballVy / currentMag) * clamped;
    }
  }

  void _acceleratePongGradually(double incrementRatio) {
    final step = _pongMaxSpeedPreset.maxSpeed * incrementRatio;
    _setBallDirectionSpeed(_pongCurrentSpeed + step);
  }

  void _onChangePongMaxSpeed(PongMaxSpeedPreset preset) {
    setState(() {
      _pongMaxSpeedPreset = preset;
      if (_pongCurrentSpeed > preset.maxSpeed) {
        _setBallDirectionSpeed(preset.maxSpeed);
      } else if (_pongCurrentSpeed < _pongInitialSpeed) {
        _setBallDirectionSpeed(_pongInitialSpeed);
      }
    });
    _emitPongState();
  }

  void _emitPongState() {
    final maxSpd = _pongMaxSpeedPreset.maxSpeed;
    final factor = maxSpd > 0
        ? (_pongCurrentSpeed / maxSpd).clamp(0.0, 1.0).toDouble()
        : 0.35;
    _pongNotifier.value = _PongFrameState(
      ballX: _ballX,
      ballY: _ballY,
      playerPaddleX: _playerPaddleX,
      cpuPaddleX: _cpuPaddleX,
      playerScore: _pongPlayerScore,
      cpuScore: _pongCpuScore,
      currentSpeedFactor: factor,
      tick: ++_pongTick,
    );
  }

  void _setupPongGame({required bool resetScore}) {
    _pongLoopTimer?.cancel();
    if (resetScore) {
      _pongPlayerScore = 0;
      _pongCpuScore = 0;
    }
    _playerPaddleX = 0.5;
    _cpuPaddleX = 0.5;
    _resetPongBall(towardPlayer: true);
    _emitPongState();

    _pongLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted ||
          _phase != SessionPhase.breakTime ||
          _selectedGame != BreakGameType.pong ||
          _isGamePaused) {
        return;
      }
      _updatePongFrame();
    });
  }

  void _resetPongBall({required bool towardPlayer}) {
    _ballX = 0.5;
    _ballY = 0.5;
    _pongCurrentSpeed = _pongInitialSpeed;
    final angle = (_random.nextDouble() * 0.6) - 0.3;
    final dirY = towardPlayer ? 1.0 : -1.0;
    _ballVx = sin(angle) * _pongCurrentSpeed;
    _ballVy = cos(angle) * _pongCurrentSpeed * dirY;
  }

  void _bounceOffPaddle({
    required double paddleX,
    required double halfPad,
    required double speedBoostRatio,
    required double steerMultiplier,
    required bool goingDown,
  }) {
    _acceleratePongGradually(speedBoostRatio);
    final hitOffset = ((_ballX - paddleX) / halfPad).clamp(-1.0, 1.0).toDouble();
    final vxNorm = ((_ballVx / _pongCurrentSpeed) + hitOffset * steerMultiplier)
        .clamp(-0.9, 0.9)
        .toDouble();
    final vyNorm = sqrt(max(0.19, 1.0 - vxNorm * vxNorm));
    _ballVx = vxNorm * _pongCurrentSpeed;
    _ballVy = (goingDown ? 1.0 : -1.0) * vyNorm * _pongCurrentSpeed;
  }

  void _updatePongFrame() {
    _acceleratePongGradually(0.00035);

    _ballX += _ballVx;
    _ballY += _ballVy;

    if (_ballX <= 0.03) {
      _ballX = 0.03;
      _ballVx = _ballVx.abs();
    } else if (_ballX >= 0.97) {
      _ballX = 0.97;
      _ballVx = -_ballVx.abs();
    }

    final cpuDiff = _ballX - _cpuPaddleX;
    if (cpuDiff.abs() > 0.01) {
      _cpuPaddleX += cpuDiff.sign * min(cpuDiff.abs(), _pongCpuSpeed);
    }
    final halfPad = _pongPaddleWidthFraction / 2;
    _cpuPaddleX = _cpuPaddleX.clamp(halfPad, 1.0 - halfPad).toDouble();

    if (_ballVy < 0 &&
        _ballY <= 0.11 &&
        _ballY >= 0.05 &&
        (_ballX - _cpuPaddleX).abs() <= halfPad + 0.035) {
      _ballY = 0.11;
      _bounceOffPaddle(
        paddleX: _cpuPaddleX,
        halfPad: halfPad,
        speedBoostRatio: 0.045,
        steerMultiplier: 0.45,
        goingDown: true,
      );
    }

    if (_ballVy > 0 &&
        _ballY >= 0.89 &&
        _ballY <= 0.95 &&
        (_ballX - _playerPaddleX).abs() <= halfPad + 0.035) {
      _ballY = 0.89;
      _bounceOffPaddle(
        paddleX: _playerPaddleX,
        halfPad: halfPad,
        speedBoostRatio: 0.055,
        steerMultiplier: 0.55,
        goingDown: false,
      );
    }

    if (_ballY < 0.0) {
      _pongPlayerScore++;
      _resetPongBall(towardPlayer: false);
    } else if (_ballY > 1.0) {
      _pongCpuScore++;
      _resetPongBall(towardPlayer: true);
    }

    _emitPongState();
  }

  void _setPlayerPaddleFromNormalizedX(double normX) {
    final halfPad = _pongPaddleWidthFraction / 2;
    _playerPaddleX = normX.clamp(halfPad, 1.0 - halfPad).toDouble();
    _emitPongState();
  }

  void _movePlayerPaddleByDelta(double deltaNormX) {
    _setPlayerPaddleFromNormalizedX(_playerPaddleX + deltaNormX);
  }

  int get _tetrisDropMs {
    switch (_difficulty) {
      case GameDifficulty.easy:
        return 650;
      case GameDifficulty.medium:
        return 420;
      case GameDifficulty.hard:
        return 240;
    }
  }

  int _computeGhostRow(List<List<int>> shape, int row, int col) {
    int ghostR = row;
    while (_canPlacePiece(shape, ghostR + 1, col)) {
      ghostR++;
    }
    return ghostR;
  }

  void _emitTetrisState() {
    if (_tetrisScore > _tetrisBestScore) {
      _tetrisBestScore = _tetrisScore;
    }
    _tetrisNotifier.value = _TetrisFrameState(
      board: _cloneMatrix(_tetrisBoard),
      activeShape: _cloneMatrix(_activePiece),
      activeRow: _activeRow,
      activeCol: _activeCol,
      ghostRow: _computeGhostRow(_activePiece, _activeRow, _activeCol),
      colorIndex: _activeColorIndex,
      score: _tetrisScore,
      bestScore: _tetrisBestScore,
      linesCleared: _tetrisLinesCleared,
      gameOver: _tetrisGameOver,
      tick: ++_tetrisTick,
    );
  }

  void _setupTetrisGame({required bool resetScore}) {
    if (resetScore) {
      _tetrisScore = 0;
      _tetrisLinesCleared = 0;
    }
    _tetrisBoard = _createEmptyTetrisBoard();
    _tetrisGameOver = false;
    _spawnNextTetromino();
    _emitTetrisState();
    _restartTetrisDropTimer();
  }

  void _restartTetrisDropTimer() {
    _tetrisDropTimer?.cancel();
    _tetrisDropTimer = Timer.periodic(
      Duration(milliseconds: _tetrisDropMs),
      (_) {
        if (!mounted ||
            _phase != SessionPhase.breakTime ||
            _selectedGame != BreakGameType.tetris ||
            _isGamePaused ||
            _tetrisGameOver) {
          return;
        }
        _stepTetrisDown(fromUserDrop: false);
      },
    );
  }

  void _spawnNextTetromino() {
    final shapeIndex = _random.nextInt(_tetrominoShapes.length);
    _activePiece = _cloneMatrix(_tetrominoShapes[shapeIndex]);
    _activeColorIndex = (shapeIndex % (_tetrisPalette.length - 1)) + 1;
    _activeRow = 0;
    _activeCol = (_tetrisCols - _activePiece[0].length) ~/ 2;

    if (!_canPlacePiece(_activePiece, _activeRow, _activeCol)) {
      _tetrisGameOver = true;
      _isGamePaused = true;
      if (mounted) {
        setState(() {});
      }
    }
  }

  bool _canPlacePiece(List<List<int>> shape, int row, int col) {
    for (int r = 0; r < shape.length; r++) {
      for (int c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 0) continue;
        final targetR = row + r;
        final targetC = col + c;
        if (targetC < 0 || targetC >= _tetrisCols || targetR >= _tetrisRows) {
          return false;
        }
        if (targetR >= 0 && _tetrisBoard[targetR][targetC] != 0) {
          return false;
        }
      }
    }
    return true;
  }

  void _lockAndClearLines() {
    for (int r = 0; r < _activePiece.length; r++) {
      for (int c = 0; c < _activePiece[r].length; c++) {
        if (_activePiece[r][c] == 0) continue;
        final targetR = _activeRow + r;
        final targetC = _activeCol + c;
        if (targetR >= 0 &&
            targetR < _tetrisRows &&
            targetC >= 0 &&
            targetC < _tetrisCols) {
          _tetrisBoard[targetR][targetC] = _activeColorIndex;
        }
      }
    }

    int clearedLines = 0;
    for (int r = _tetrisRows - 1; r >= 0; r--) {
      if (_tetrisBoard[r].every((cell) => cell != 0)) {
        _tetrisBoard.removeAt(r);
        _tetrisBoard.insert(0, List.filled(_tetrisCols, 0));
        clearedLines++;
        r++;
      }
    }

    if (clearedLines > 0) {
      _tetrisLinesCleared += clearedLines;
      final baseLinePoints = switch (clearedLines) {
        1 => 100,
        2 => 300,
        3 => 500,
        _ => 800,
      };
      final diffMultiplier = switch (_difficulty) {
        GameDifficulty.easy => 1,
        GameDifficulty.medium => 2,
        GameDifficulty.hard => 3,
      };
      _tetrisScore += baseLinePoints * diffMultiplier;
    }

    _spawnNextTetromino();
  }

  void _stepTetrisDown({bool fromUserDrop = true}) {
    if (_isGamePaused || _tetrisGameOver) return;
    if (_canPlacePiece(_activePiece, _activeRow + 1, _activeCol)) {
      _activeRow++;
      if (fromUserDrop) {
        _tetrisScore += 1;
      }
    } else {
      _lockAndClearLines();
    }
    _emitTetrisState();
  }

  void _moveTetrisHorizontal(int dc) {
    if (_isGamePaused || _tetrisGameOver) return;
    if (_canPlacePiece(_activePiece, _activeRow, _activeCol + dc)) {
      _activeCol += dc;
      _emitTetrisState();
    }
  }

  void _rotateTetrisPiece() {
    if (_isGamePaused || _tetrisGameOver) return;
    final rows = _activePiece.length;
    final cols = _activePiece[0].length;
    final rotated = List.generate(
      cols,
      (c) => List.generate(rows, (r) => _activePiece[rows - 1 - r][c]),
    );

    const colOffsets = [0, -1, 1];
    for (final offset in colOffsets) {
      final candidateCol = _activeCol + offset;
      if (_canPlacePiece(rotated, _activeRow, candidateCol)) {
        _activeCol = candidateCol;
        _activePiece = rotated;
        _emitTetrisState();
        return;
      }
    }
  }

  void _dropTetrisHard() {
    if (_isGamePaused || _tetrisGameOver) return;
    int droppedRows = 0;
    while (_canPlacePiece(_activePiece, _activeRow + 1, _activeCol)) {
      _activeRow++;
      droppedRows++;
    }
    _tetrisScore += droppedRows * 2;
    _lockAndClearLines();
    _emitTetrisState();
  }

  KeyEventResult _handleArcadeKeyEvent(FocusNode node, KeyEvent event) {
    if (_phase != SessionPhase.breakTime || _isGamePaused) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_selectedGame == BreakGameType.pong) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        _movePlayerPaddleByDelta(-0.06);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        _movePlayerPaddleByDelta(0.06);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (_selectedGame == BreakGameType.tetris) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        _moveTetrisHorizontal(-1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        _moveTetrisHorizontal(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.keyS) {
        _stepTetrisDown(fromUserDrop: true);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.keyW) {
        _rotateTetrisPiece();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _dropTetrisHard();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _addTopic() {
    final title = _newTopicController.text.trim();
    if (title.isEmpty) return;

    final newTopic = StudyTopic(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
    );

    setState(() {
      _topics.insert(0, newTopic);
      _selectedTopicId = newTopic.id;
      _newTopicController.clear();
      _syncControllersWithSelectedTopic();
    });
  }

  void _selectTopic(StudyTopic topic) {
    setState(() {
      _selectedTopicId = topic.id;
      _syncControllersWithSelectedTopic();
    });
  }

  void _toggleTopicCompleted(StudyTopic topic) {
    setState(() {
      topic.isCompleted = !topic.isCompleted;
    });
  }

  void _deleteTopic(String id) {
    setState(() {
      _topics.removeWhere((t) => t.id == id);
      if (_selectedTopicId == id) {
        _selectedTopicId = _topics.isNotEmpty ? _topics.first.id : null;
        _syncControllersWithSelectedTopic();
      }
    });
  }

  String _formatClock(int totalSeconds) {
    final safeSeconds = max(0, totalSeconds);
    final m = (safeSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (safeSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatTotalStudied(int totalSeconds) {
    final safeSeconds = max(0, totalSeconds);
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAllGames();
    _pongNotifier.dispose();
    _tetrisNotifier.dispose();
    _arcadeFocusNode.dispose();
    _newTopicController.dispose();
    _noteEditorController.dispose();
    _topicTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStudy = _phase == SessionPhase.study;
    final total = _currentPhaseTotalSeconds;
    final elapsed = (total - _remainingSeconds).clamp(0, total).toInt();
    final activeTopic = _selectedTopic;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Notes Pro'),
        actions: [
          IconButton(
            tooltip: 'Restaurar tamanhos padrão',
            onPressed: _resetAreasSize,
            icon: const Icon(Icons.restore),
          ),
          Chip(
            avatar: const Icon(Icons.local_fire_department, size: 18),
            label: Text('Estudado: ${_formatTotalStudied(_totalStudiedSeconds)}'),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Configurar tempos',
            onPressed: _openDurationDialog,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 860;
          final leftColumn = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _timerAreaHeight,
                child: _TimerCard(
                  isStudy: isStudy,
                  studyMinutes: _studyMinutes,
                  breakMinutes: _breakMinutes,
                  remainingSeconds: _remainingSeconds,
                  totalSeconds: total,
                  elapsedSeconds: elapsed,
                  isRunning: _isRunning,
                  activeTopicTitle: activeTopic?.title,
                  formatClock: _formatClock,
                  onAdvancePhase: _advancePhase,
                  onSeekElapsed: _seekToElapsedSeconds,
                  onJumpSeconds: _jumpSeconds,
                  onRewindOrRestart: _rewindOrRestartPhase,
                  onTogglePlayPause: _togglePlayPause,
                ),
              ),
              _ResizeHandle(
                axis: Axis.vertical,
                tooltip: 'Arraste para ajustar a altura do Timer',
                onDragDelta: _dragTimerHeight,
              ),
              if (!isStudy) ...[
                SizedBox(
                  height: _gameAreaHeight,
                  child: _buildBreakArcadeCard(context),
                ),
                _ResizeHandle(
                  axis: Axis.vertical,
                  tooltip: 'Arraste para ajustar a altura do Joguinho',
                  onDragDelta: _dragGameHeight,
                ),
              ],
            ],
          );

          final notesCard = _buildNotesWorkspace(context, activeTopic);

          if (isWide) {
            final maxNotesW =
                (constraints.maxWidth - 360).clamp(300.0, 950.0).toDouble();
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(child: leftColumn),
                  ),
                  _ResizeHandle(
                    axis: Axis.horizontal,
                    tooltip: 'Arraste para redimensionar o Bloco de Notas',
                    onDragDelta: (dx) => _dragNotesExtent(-dx),
                  ),
                  SizedBox(
                    width: _notesAreaExtent.clamp(300.0, maxNotesW).toDouble(),
                    child: notesCard,
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leftColumn,
                _ResizeHandle(
                  axis: Axis.vertical,
                  tooltip: 'Arraste para ajustar a altura do Bloco de Notas',
                  onDragDelta: _dragNotesExtent,
                ),
                SizedBox(height: _notesAreaExtent, child: notesCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBreakArcadeCard(BuildContext context) {
    final actionLabel = !_hasGameStarted
        ? 'Começar'
        : (_isGamePaused ? 'Retomar' : 'Pausar');
    final actionIcon =
        !_hasGameStarted || _isGamePaused ? Icons.play_arrow : Icons.pause;

    return Focus(
      focusNode: _arcadeFocusNode,
      onKeyEvent: _handleArcadeKeyEvent,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<BreakGameType>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(
                            value: BreakGameType.reflex,
                            icon: Icon(Icons.bolt, size: 16),
                            label: Text('Reflexo'),
                          ),
                          ButtonSegment(
                            value: BreakGameType.pong,
                            icon: Icon(Icons.sports_tennis, size: 16),
                            label: Text('Pong'),
                          ),
                          ButtonSegment(
                            value: BreakGameType.tetris,
                            icon: Icon(Icons.grid_view_rounded, size: 16),
                            label: Text('Tetris'),
                          ),
                        ],
                        selected: {_selectedGame},
                        onSelectionChanged: (set) => _onSelectGame(set.first),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_selectedGame == BreakGameType.pong)
                    DropdownButton<PongMaxSpeedPreset>(
                      value: _pongMaxSpeedPreset,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      items: PongMaxSpeedPreset.values
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.label),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) _onChangePongMaxSpeed(val);
                      },
                    )
                  else
                    DropdownButton<GameDifficulty>(
                      value: _difficulty,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      items: GameDifficulty.values
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text(d.label),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) _onChangeDifficulty(val);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _startOrToggleGamePause,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    icon: Icon(actionIcon, size: 16),
                    label: Text(actionLabel),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Reiniciar jogo',
                    visualDensity: VisualDensity.compact,
                    onPressed: _restartCurrentGame,
                    icon: const Icon(Icons.replay, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: switch (_selectedGame) {
                          BreakGameType.reflex => Text(
                              'Pts: $_reflexScore • Rec: $_reflexBestScore',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          BreakGameType.pong =>
                            ValueListenableBuilder<_PongFrameState>(
                              valueListenable: _pongNotifier,
                              builder: (context, frame, _) {
                                final pct =
                                    (frame.currentSpeedFactor * 100).round();
                                return Text(
                                  'Você ${frame.playerScore} × ${frame.cpuScore} CPU • Vel: $pct%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                            ),
                          BreakGameType.tetris =>
                            ValueListenableBuilder<_TetrisFrameState>(
                              valueListenable: _tetrisNotifier,
                              builder: (context, frame, _) => Text(
                                'Pts: ${frame.score} • Linhas: ${frame.linesCleared} • Rec: ${frame.bestScore}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: switch (_selectedGame) {
                  BreakGameType.reflex => _buildReflexArena(),
                  BreakGameType.pong => _buildPongArena(),
                  BreakGameType.tetris => _buildTetrisArena(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPausedOverlay() {
    if (!_isGamePaused ||
        (_selectedGame == BreakGameType.tetris && _tetrisGameOver)) {
      return const SizedBox.shrink();
    }
    final label = !_hasGameStarted ? 'Começar Jogo' : 'Jogo Pausado • Retomar';
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: FilledButton.icon(
            onPressed: _startOrToggleGamePause,
            icon: const Icon(Icons.play_arrow),
            label: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _buildReflexArena() {
    final btnSize = _reflexButtonSize;
    final accentColor = switch (_difficulty) {
      GameDifficulty.easy => Colors.tealAccent,
      GameDifficulty.medium => Colors.cyanAccent,
      GameDifficulty.hard => Colors.orangeAccent,
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141829), Color(0xFF1E1633)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxLeft = (constraints.maxWidth - btnSize)
              .clamp(0.0, double.infinity)
              .toDouble();
          final maxTop = (constraints.maxHeight - btnSize)
              .clamp(0.0, double.infinity)
              .toDouble();

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOutCubic,
                left: maxLeft * _targetX,
                top: maxTop * _targetY,
                child: GestureDetector(
                  onTap: _onReflexTargetTap,
                  child: Container(
                    width: btnSize,
                    height: btnSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.white, accentColor],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      size: btnSize * 0.56,
                      color: const Color(0xFF0D101B),
                    ),
                  ),
                ),
              ),
              _buildPausedOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPongArena() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        void updatePaddle(double localX) {
          if (_isGamePaused || w <= 0) return;
          _requestArcadeFocusIfAppropriate();
          _setPlayerPaddleFromNormalizedX(localX / w);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) =>
              updatePaddle(_playerPaddleX * w + details.delta.dx),
          onTapDown: (details) => updatePaddle(details.localPosition.dx),
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0E1624), Color(0xFF142238)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ValueListenableBuilder<_PongFrameState>(
                    valueListenable: _pongNotifier,
                    builder: (context, frame, _) => CustomPaint(
                      painter: _PongCanvasPainter(
                        ballX: frame.ballX,
                        ballY: frame.ballY,
                        playerPaddleX: frame.playerPaddleX,
                        cpuPaddleX: frame.cpuPaddleX,
                        paddleWidthFraction: _pongPaddleWidthFraction,
                      ),
                    ),
                  ),
                ),
                _buildPausedOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTetrisControlButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback action,
  }) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        _requestArcadeFocusIfAppropriate();
        action();
      },
      icon: Icon(icon),
    );
  }

  Widget _buildTetrisArena() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _requestArcadeFocusIfAppropriate,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E1320),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.purpleAccent.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: _tetrisCols / _tetrisRows,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF080B14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ValueListenableBuilder<_TetrisFrameState>(
                          valueListenable: _tetrisNotifier,
                          builder: (context, frame, _) => CustomPaint(
                            painter: _TetrisCanvasPainter(
                              rows: _tetrisRows,
                              cols: _tetrisCols,
                              board: frame.board,
                              activeShape: frame.activeShape,
                              activeRow: frame.activeRow,
                              activeCol: frame.activeCol,
                              ghostRow: frame.ghostRow,
                              colorIndex: frame.colorIndex,
                              palette: _tetrisPalette,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<_TetrisFrameState>(
                    valueListenable: _tetrisNotifier,
                    builder: (context, frame, _) {
                      if (!frame.gameOver) return const SizedBox.shrink();
                      return Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Fim de jogo no Tetris',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Pontuação final: ${frame.score}'),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: _restartCurrentGame,
                                icon: const Icon(Icons.replay),
                                label: const Text('Jogar Novamente'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  _buildPausedOverlay(),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildTetrisControlButton(
                  tooltip: 'Mover esquerda (← / A)',
                  icon: Icons.arrow_left,
                  action: () => _moveTetrisHorizontal(-1),
                ),
                _buildTetrisControlButton(
                  tooltip: 'Girar peça (↑ / W)',
                  icon: Icons.rotate_right,
                  action: _rotateTetrisPiece,
                ),
                _buildTetrisControlButton(
                  tooltip: 'Descer rápido (↓ / S)',
                  icon: Icons.arrow_downward,
                  action: () => _stepTetrisDown(fromUserDrop: true),
                ),
                _buildTetrisControlButton(
                  tooltip: 'Queda direta (Espaço)',
                  icon: Icons.vertical_align_bottom,
                  action: _dropTetrisHard,
                ),
                _buildTetrisControlButton(
                  tooltip: 'Mover direita (→ / D)',
                  icon: Icons.arrow_right,
                  action: () => _moveTetrisHorizontal(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesWorkspace(BuildContext context, StudyTopic? activeTopic) {
    final completedCount = _topics.where((t) => t.isCompleted).length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tópicos de Estudo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('$completedCount/${_topics.length} concluídos'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTopicController,
                    onSubmitted: (_) => _addTopic(),
                    decoration: const InputDecoration(
                      hintText: 'Novo tópico (ex: Química Orgânica)...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addTopic,
                  child: const Text('Criar'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: _topics.isEmpty
                  ? const Center(child: Text('Nenhum tópico criado ainda.'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _topics.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final topic = _topics[index];
                        final isSelected = topic.id == _selectedTopicId;
                        return InputChip(
                          selected: isSelected,
                          avatar: GestureDetector(
                            onTap: () => _toggleTopicCompleted(topic),
                            child: Icon(
                              topic.isCompleted
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: topic.isCompleted
                                  ? Colors.tealAccent
                                  : null,
                            ),
                          ),
                          label: Text(
                            topic.title,
                            style: TextStyle(
                              decoration: topic.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          onPressed: () => _selectTopic(topic),
                          onDeleted: () => _deleteTopic(topic.id),
                        );
                      },
                    ),
            ),
            const Divider(height: 20),
            if (activeTopic == null)
              const Expanded(
                child: Center(child: Text('Crie ou selecione um tópico acima.')),
              )
            else ...[
              Row(
                children: [
                  IconButton(
                    tooltip: activeTopic.isCompleted
                        ? 'Marcar como não concluído'
                        : 'Dar tópico como concluído',
                    onPressed: () => _toggleTopicCompleted(activeTopic),
                    icon: Icon(
                      activeTopic.isCompleted
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: activeTopic.isCompleted
                          ? Colors.tealAccent
                          : Colors.white60,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _topicTitleController,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        decoration: activeTopic.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Título do tópico',
                      ),
                      onChanged: (val) =>
                          setState(() => activeTopic.title = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _toggleTopicCompleted(activeTopic),
                    icon: Icon(
                      activeTopic.isCompleted ? Icons.check : Icons.done_all,
                      size: 18,
                    ),
                    label: Text(
                      activeTopic.isCompleted ? 'Concluído' : 'Concluir',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: _noteEditorController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText:
                        'Anote resumos, fórmulas, links e pontos importantes...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => activeTopic.notes = val,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  final bool isStudy;
  final int studyMinutes;
  final int breakMinutes;
  final int remainingSeconds;
  final int totalSeconds;
  final int elapsedSeconds;
  final bool isRunning;
  final String? activeTopicTitle;
  final String Function(int) formatClock;
  final VoidCallback onAdvancePhase;
  final ValueChanged<int> onSeekElapsed;
  final ValueChanged<int> onJumpSeconds;
  final VoidCallback onRewindOrRestart;
  final VoidCallback onTogglePlayPause;

  const _TimerCard({
    required this.isStudy,
    required this.studyMinutes,
    required this.breakMinutes,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.elapsedSeconds,
    required this.isRunning,
    required this.activeTopicTitle,
    required this.formatClock,
    required this.onAdvancePhase,
    required this.onSeekElapsed,
    required this.onJumpSeconds,
    required this.onRewindOrRestart,
    required this.onTogglePlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final safeMax = max(1, totalSeconds).toDouble();
    final safeValue = elapsedSeconds.toDouble().clamp(0.0, safeMax).toDouble();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isStudy
                      ? 'ESTUDO ($studyMinutes min)'
                      : 'INTERVALO ($breakMinutes min)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: isStudy ? Colors.amberAccent : Colors.tealAccent,
                  ),
                ),
                TextButton(
                  onPressed: onAdvancePhase,
                  child: Text(isStudy ? 'Ir p/ Intervalo' : 'Ir p/ Estudo'),
                ),
              ],
            ),
            Text(
              activeTopicTitle != null
                  ? 'Tópico ativo: $activeTopicTitle'
                  : 'Nenhum tópico selecionado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatClock(remainingSeconds),
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Slider(
              value: safeValue,
              min: 0,
              max: safeMax,
              onChanged: (val) => onSeekElapsed(val.round()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Decorrido: ${formatClock(elapsedSeconds)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Total: ${formatClock(totalSeconds)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton(
                  onPressed: () => onJumpSeconds(-10),
                  child: const Text('-10s'),
                ),
                IconButton.filledTonal(
                  tooltip: 'Reiniciar / Etapa anterior',
                  onPressed: onRewindOrRestart,
                  icon: const Icon(Icons.skip_previous),
                ),
                FilledButton.icon(
                  onPressed: onTogglePlayPause,
                  icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(isRunning ? 'Pausar' : 'Iniciar'),
                ),
                IconButton.filledTonal(
                  tooltip: 'Avançar etapa',
                  onPressed: onAdvancePhase,
                  icon: const Icon(Icons.skip_next),
                ),
                OutlinedButton(
                  onPressed: () => onJumpSeconds(10),
                  child: const Text('+10s'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PongCanvasPainter extends CustomPainter {
  final double ballX;
  final double ballY;
  final double playerPaddleX;
  final double cpuPaddleX;
  final double paddleWidthFraction;

  _PongCanvasPainter({
    required this.ballX,
    required this.ballY,
    required this.playerPaddleX,
    required this.cpuPaddleX,
    required this.paddleWidthFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final centerLinePaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(16, h / 2), Offset(w - 16, h / 2), centerLinePaint);
    canvas.drawCircle(Offset(w / 2, h / 2), 24, centerLinePaint);

    final paddleW = w * paddleWidthFraction;
    const paddleH = 11.0;

    final cpuRect = RRect.fromRectAndRadius(
      Rect.fromLTWH((w * cpuPaddleX) - paddleW / 2, h * 0.08, paddleW, paddleH),
      const Radius.circular(999),
    );
    canvas.drawRRect(cpuRect, Paint()..color = Colors.redAccent);

    final playerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (w * playerPaddleX) - paddleW / 2,
        h * 0.90,
        paddleW,
        paddleH,
      ),
      const Radius.circular(999),
    );
    canvas.drawRRect(playerRect, Paint()..color = Colors.tealAccent);

    canvas.drawCircle(
      Offset(w * ballX, h * ballY),
      7.0,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PongCanvasPainter oldDelegate) {
    return oldDelegate.ballX != ballX ||
        oldDelegate.ballY != ballY ||
        oldDelegate.playerPaddleX != playerPaddleX ||
        oldDelegate.cpuPaddleX != cpuPaddleX ||
        oldDelegate.paddleWidthFraction != paddleWidthFraction;
  }
}

class _TetrisCanvasPainter extends CustomPainter {
  final int rows;
  final int cols;
  final List<List<int>> board;
  final List<List<int>> activeShape;
  final int activeRow;
  final int activeCol;
  final int ghostRow;
  final int colorIndex;
  final List<Color> palette;

  _TetrisCanvasPainter({
    required this.rows,
    required this.cols,
    required this.board,
    required this.activeShape,
    required this.activeRow,
    required this.activeCol,
    required this.ghostRow,
    required this.colorIndex,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (int r = 0; r <= rows; r++) {
      canvas.drawLine(
        Offset(0, r * cellH),
        Offset(size.width, r * cellH),
        gridPaint,
      );
    }
    for (int c = 0; c <= cols; c++) {
      canvas.drawLine(
        Offset(c * cellW, 0),
        Offset(c * cellW, size.height),
        gridPaint,
      );
    }

    void drawPieceMatrix(
      List<List<int>> matrix,
      int baseRow,
      int baseCol, {
      required bool isGhost,
    }) {
      if (colorIndex <= 0 || colorIndex >= palette.length) return;
      final baseColor = palette[colorIndex];

      for (int r = 0; r < matrix.length; r++) {
        for (int c = 0; c < matrix[r].length; c++) {
          if (matrix[r][c] == 0) continue;
          final drawR = baseRow + r;
          final drawC = baseCol + c;
          if (drawR < 0 || drawR >= rows || drawC < 0 || drawC >= cols) continue;

          if (isGhost) {
            final rect = RRect.fromRectAndRadius(
              Rect.fromLTWH(
                drawC * cellW + 1.5,
                drawR * cellH + 1.5,
                cellW - 3.0,
                cellH - 3.0,
              ),
              const Radius.circular(3),
            );
            canvas.drawRRect(
              rect,
              Paint()..color = baseColor.withValues(alpha: 0.16),
            );
            canvas.drawRRect(
              rect,
              Paint()
                ..color = baseColor.withValues(alpha: 0.65)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.2,
            );
          } else {
            final rect = RRect.fromRectAndRadius(
              Rect.fromLTWH(
                drawC * cellW + 1.2,
                drawR * cellH + 1.2,
                cellW - 2.4,
                cellH - 2.4,
              ),
              const Radius.circular(3),
            );
            canvas.drawRRect(rect, Paint()..color = baseColor);
          }
        }
      }
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cIdx = board[r][c];
        if (cIdx > 0 && cIdx < palette.length) {
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              c * cellW + 1.2,
              r * cellH + 1.2,
              cellW - 2.4,
              cellH - 2.4,
            ),
            const Radius.circular(3),
          );
          canvas.drawRRect(rect, Paint()..color = palette[cIdx]);
        }
      }
    }

    if (ghostRow > activeRow) {
      drawPieceMatrix(activeShape, ghostRow, activeCol, isGhost: true);
    }
    drawPieceMatrix(activeShape, activeRow, activeCol, isGhost: false);
  }

  @override
  bool shouldRepaint(covariant _TetrisCanvasPainter oldDelegate) {
    return oldDelegate.activeRow != activeRow ||
        oldDelegate.activeCol != activeCol ||
        oldDelegate.ghostRow != ghostRow ||
        oldDelegate.colorIndex != colorIndex ||
        oldDelegate.board != board ||
        oldDelegate.activeShape != activeShape;
  }
}

class _ResizeHandle extends StatefulWidget {
  final Axis axis;
  final String tooltip;
  final ValueChanged<double> onDragDelta;

  const _ResizeHandle({
    required this.axis,
    required this.tooltip,
    required this.onDragDelta,
  });

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging;
    final color =
        active ? Theme.of(context).colorScheme.primary : Colors.white24;
    final isVertical = widget.axis == Axis.vertical;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: isVertical
            ? SystemMouseCursors.resizeRow
            : SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => setState(() => _dragging = true),
          onPanEnd: (_) => setState(() => _dragging = false),
          onPanCancel: () => setState(() => _dragging = false),
          onPanUpdate: (details) => widget.onDragDelta(
            isVertical ? details.delta.dy : details.delta.dx,
          ),
          child: Container(
            width: isVertical ? null : 16,
            height: isVertical ? 16 : null,
            alignment: Alignment.center,
            child: Container(
              width: isVertical ? 48 : 4,
              height: isVertical ? 4 : 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _DurationStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(
              onPressed: value > min
                  ? () => onChanged((value - step).clamp(min, max).toInt())
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '$value min',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: value < max
                  ? () => onChanged((value + step).clamp(min, max).toInt())
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }
}