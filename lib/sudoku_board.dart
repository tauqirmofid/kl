import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HighScore {
  final int time; // in milliseconds
  final int lives;

  HighScore({required this.time, required this.lives});

  Map<String, dynamic> toJson() {
    return {'time': time, 'lives': lives};
  }

  factory HighScore.fromJson(Map<String, dynamic> json) {
    return HighScore(time: json['time'], lives: json['lives']);
  }
}

class SudokuBoard extends StatefulWidget {
  const SudokuBoard({Key? key}) : super(key: key);

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard>
    with TickerProviderStateMixin {
  List<List<int>> _board =
  List.generate(9, (_) => List.generate(9, (_) => 0));

  // Added variable to store the solution board
  late List<List<int>> _solutionBoard;

  List<List<bool>> _isEditable =
  List.generate(9, (_) => List.generate(9, (_) => true));
  int? _selectedNumber;
  int? _selectedRow;
  int? _selectedCol;
  int _lives = 5;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // For Undo functionality
  final List<Map<String, dynamic>> _moveHistory = [];

  // Difficulty Level
  String _difficultyLevel = 'Easy';

  // Completed Rows, Columns, Blocks
  List<bool> _completedRows = List.generate(9, (_) => false);
  List<bool> _completedCols = List.generate(9, (_) => false);
  List<bool> _completedBlocks = List.generate(9, (_) => false);

  // Number Usage Count
  Map<int, int> _numberUsageCount = {};

  // Animation Controllers for Lines/Blocks
  List<AnimationController> _lineAnimations = [];
  List<AnimationController> _columnAnimations = [];
  List<AnimationController> _blockAnimations = [];

  // Animation Controller for Number Pad Buttons
  Map<int, AnimationController> _numberPadAnimations = {};

  // Timer and Stopwatch
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  String _elapsedTime = '00:00';

  // High Scores
  Map<String, List<HighScore>> _highScores = {
    'Easy': [],
    'Medium': [],
    'Hard': [],
  };

  @override
  void initState() {
    super.initState();

    // Initialize fade animation controller and animation
    _fadeController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true); // Repeats fade-in and fade-out

    _fadeAnimation =
        Tween<double>(begin: 0.3, end: 1.0).animate(_fadeController);

    // Initialize line, column, and block animation controllers
    _lineAnimations = List.generate(
        9,
            (_) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 500)));
    _columnAnimations = List.generate(
        9,
            (_) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 500)));
    _blockAnimations = List.generate(
        9,
            (_) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 500)));

    // Initialize number pad animations
    for (int i = 1; i <= 9; i++) {
      _numberPadAnimations[i] = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      );
    }

    // Initialize number usage count
    _numberUsageCount = {};
    for (var i = 1; i <= 9; i++) {
      _numberUsageCount[i] = 0;
    }

    // Proceed with asynchronous initialization
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    await _loadHighScores();

    // Start the game by showing the difficulty dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDifficultyDialog();
    });
  }

  Future<void> _loadHighScores() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      for (String difficulty in ['Easy', 'Medium', 'Hard']) {
        List<String>? highScoreStrings =
        prefs.getStringList('highScores_$difficulty');
        if (highScoreStrings != null) {
          _highScores[difficulty] = highScoreStrings.map((scoreString) {
            Map<String, dynamic> json =
            Map<String, dynamic>.from(jsonDecode(scoreString));
            return HighScore.fromJson(json);
          }).toList();
        }
      }
    });
  }

  void _saveHighScores() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (String difficulty in ['Easy', 'Medium', 'Hard']) {
      List<String> highScoreStrings = _highScores[difficulty]!.map((score) {
        return jsonEncode(score.toJson());
      }).toList();
      await prefs.setStringList('highScores_$difficulty', highScoreStrings);
    }
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Difficulty',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.looks_one, color: Colors.blue),
                  title: const Text('Easy'),
                  onTap: () {
                    _difficultyLevel = 'Easy';
                    Navigator.of(context).pop();
                    _generatePuzzle();
                  },
                ),
                ListTile(
                  leading:
                  const Icon(Icons.looks_two, color: Colors.orange),
                  title: const Text('Medium'),
                  onTap: () {
                    _difficultyLevel = 'Medium';
                    Navigator.of(context).pop();
                    _generatePuzzle();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.looks_3, color: Colors.red),
                  title: const Text('Hard'),
                  onTap: () {
                    _difficultyLevel = 'Hard';
                    Navigator.of(context).pop();
                    _generatePuzzle();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _generatePuzzle() {
    // Generate a complete valid Sudoku puzzle
    _solutionBoard = _generateCompleteBoard();

    // Create a copy of the solution to make the puzzle
    _board = _copyBoard(_solutionBoard);

    // Remove numbers to create the puzzle
    _removeNumbers();

    // Set the editable cells
    _isEditable = List.generate(
      9,
          (i) => List.generate(
        9,
            (j) => _board[i][j] == 0,
      ),
    );

    // Initialize number usage count
    _numberUsageCount = {};
    for (int i = 1; i <= 9; i++) {
      _numberUsageCount[i] = _countNumberInBoard(i);
    }

    // Reset animations
    for (var controller in _numberPadAnimations.values) {
      controller.reset();
    }
    for (var controller in _lineAnimations) {
      controller.reset();
    }
    for (var controller in _columnAnimations) {
      controller.reset();
    }
    for (var controller in _blockAnimations) {
      controller.reset();
    }

    setState(() {
      _lives = 5; // Reset lives
      _selectedRow = null;
      _selectedCol = null;
      _selectedNumber = null;
      _moveHistory.clear(); // Clear move history
      _completedRows = List.generate(9, (_) => false);
      _completedCols = List.generate(9, (_) => false);
      _completedBlocks = List.generate(9, (_) => false);
      _elapsedTime = '00:00';
    });

    // Start the stopwatch and timer
    _stopwatch.reset();
    _stopwatch.start();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = _formatElapsedTime(_stopwatch.elapsedMilliseconds);
      });
    });
  }

  String _formatElapsedTime(int milliseconds) {
    int seconds = milliseconds ~/ 1000;
    int minutes = seconds ~/ 60;
    seconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _countNumberInBoard(int number) {
    int count = 0;
    for (var row in _board) {
      count += row.where((n) => n == number).length;
    }
    return count;
  }

  List<List<int>> _generateCompleteBoard() {
    List<List<int>> board =
    List.generate(9, (_) => List.generate(9, (_) => 0));
    _fillBoard(board);
    return board;
  }

  bool _fillBoard(List<List<int>> board) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          List<int> numbers = List<int>.generate(9, (index) => index + 1);
          numbers.shuffle();
          for (int number in numbers) {
            if (_isValidPlacementStatic(board, row, col, number)) {
              board[row][col] = number;
              if (_fillBoard(board)) {
                return true;
              }
              board[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  void _removeNumbers() {
    int cellsToRemove;
    switch (_difficultyLevel) {
      case 'Easy':
        cellsToRemove = 35;
        break;
      case 'Medium':
        cellsToRemove = 45;
        break;
      case 'Hard':
        cellsToRemove = 55;
        break;
      default:
        cellsToRemove = 40;
    }

    Random rand = Random();

    while (cellsToRemove > 0) {
      int row = rand.nextInt(9);
      int col = rand.nextInt(9);

      if (_board[row][col] != 0) {
        int backup = _board[row][col];
        _board[row][col] = 0;

        if (!_hasUniqueSolution(_copyBoard(_board))) {
          _board[row][col] = backup; // Restore if solution is not unique
        } else {
          cellsToRemove--;
        }
      }
    }

    // Ensure no rows, columns, or blocks are fully completed in initial puzzle
    for (int i = 0; i < 9; i++) {
      if (_board[i].where((n) => n != 0).length == 9) {
        // Remove a random number from the row
        int col = rand.nextInt(9);
        _board[i][col] = 0;
      }
      // Similar checks for columns and blocks...
      List<int> colNumbers = [];
      for (int j = 0; j < 9; j++) {
        colNumbers.add(_board[j][i]);
      }
      if (colNumbers.where((n) => n != 0).length == 9) {
        // Remove a random number from the column
        int row = rand.nextInt(9);
        _board[row][i] = 0;
      }
    }
    // Similarly for blocks (3x3 grids)
    for (int block = 0; block < 9; block++) {
      int startRow = (block ~/ 3) * 3;
      int startCol = (block % 3) * 3;
      List<int> blockNumbers = [];
      for (int i = startRow; i < startRow + 3; i++) {
        for (int j = startCol; j < startCol + 3; j++) {
          blockNumbers.add(_board[i][j]);
        }
      }
      if (blockNumbers.where((n) => n != 0).length == 9) {
        // Remove a random number from the block
        int row = startRow + rand.nextInt(3);
        int col = startCol + rand.nextInt(3);
        _board[row][col] = 0;
      }
    }
  }

  List<List<int>> _copyBoard(List<List<int>> board) {
    return board.map((row) => row.toList()).toList();
  }

  bool _isValidPlacementStatic(
      List<List<int>> board, int row, int col, int number) {
    for (int i = 0; i < 9; i++) {
      if (board[row][i] == number || board[i][col] == number) return false;
    }

    int startRow = (row ~/ 3) * 3;
    int startCol = (col ~/ 3) * 3;

    for (int i = startRow; i < startRow + 3; i++) {
      for (int j = startCol; j < startCol + 3; j++) {
        if (board[i][j] == number) return false;
      }
    }

    return true;
  }

  bool _hasUniqueSolution(List<List<int>> board) {
    _solutions = 0;
    _solve(board);
    return _solutions == 1;
  }

  int _solutions = 0;

  bool _solve(List<List<int>> board) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          for (int number = 1; number <= 9; number++) {
            if (_isValidPlacementStatic(board, row, col, number)) {
              board[row][col] = number;
              if (_solve(board)) return true;
              board[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    _solutions++;
    return _solutions == 1;
  }

  void _placeNumber() {
    if (_selectedRow != null &&
        _selectedCol != null &&
        _selectedNumber != null) {
      if (_isEditable[_selectedRow!][_selectedCol!]) {
        // Check if the selected number matches the solution
        if (_selectedNumber == _solutionBoard[_selectedRow!][_selectedCol!]) {
          // Save the move for undo
          _moveHistory.add({
            'row': _selectedRow!,
            'col': _selectedCol!,
            'prevValue': _board[_selectedRow!][_selectedCol!],
          });

          setState(() {
            _board[_selectedRow!][_selectedCol!] = _selectedNumber!;
            _numberUsageCount[_selectedNumber!] =
                (_numberUsageCount[_selectedNumber!] ?? 0) + 1;

            // Check if number has been used 9 times
            if (_numberUsageCount[_selectedNumber!] == 9) {
              // Start animation for number pad button
              _numberPadAnimations[_selectedNumber!]!.forward();
            }

            _selectedRow = null;
            _selectedCol = null;
            _selectedNumber = null;
          });
          _checkCompletedLines();
          _checkCompletion();
        } else {
          setState(() {
            _lives -= 1;
            if (_lives == 0) {
              _showGameOverDialog();
            } else {
              _showInvalidMoveDialog();
            }
          });
        }
      }
    }
  }

  void _checkCompletedLines() {
    // Reset completed lines before checking
    _completedRows = List.generate(9, (_) => false);
    _completedCols = List.generate(9, (_) => false);
    _completedBlocks = List.generate(9, (_) => false);

    // Check rows
    for (int i = 0; i < 9; i++) {
      bool hasEmptyCell = false;
      List<int> numbers = [];
      for (int j = 0; j < 9; j++) {
        if (_board[i][j] == 0) {
          hasEmptyCell = true;
          break;
        }
        numbers.add(_board[i][j]);
      }
      if (!hasEmptyCell && numbers.toSet().length == 9) {
        if (!_completedRows[i]) {
          _completedRows[i] = true;
          // Start animation for the row
          _lineAnimations[i].forward(from: 0.0);
        }
      }
    }

    // Check columns
    for (int i = 0; i < 9; i++) {
      bool hasEmptyCell = false;
      List<int> numbers = [];
      for (int j = 0; j < 9; j++) {
        if (_board[j][i] == 0) {
          hasEmptyCell = true;
          break;
        }
        numbers.add(_board[j][i]);
      }
      if (!hasEmptyCell && numbers.toSet().length == 9) {
        if (!_completedCols[i]) {
          _completedCols[i] = true;
          // Start animation for the column
          _columnAnimations[i].forward(from: 0.0);
        }
      }
    }

    // Check blocks
    for (int block = 0; block < 9; block++) {
      int startRow = (block ~/ 3) * 3;
      int startCol = (block % 3) * 3;
      bool hasEmptyCell = false;
      List<int> numbers = [];
      for (int i = startRow; i < startRow + 3; i++) {
        for (int j = startCol; j < startCol + 3; j++) {
          if (_board[i][j] == 0) {
            hasEmptyCell = true;
            break;
          }
          numbers.add(_board[i][j]);
        }
      }
      if (!hasEmptyCell && numbers.toSet().length == 9) {
        if (!_completedBlocks[block]) {
          _completedBlocks[block] = true;
          // Start animation for the block
          _blockAnimations[block].forward(from: 0.0);
        }
      }
    }
  }

  void _checkCompletion() {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (_board[i][j] == 0) {
          return;
        }
      }
    }

    // If all cells are filled, the puzzle is completed
    _showCompletionDialog();
  }

  void _showInvalidMoveDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.red[600],
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 24,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invalid',
                  style: TextStyle(
                    color: Colors.yellowAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This move is invalid!\nLives left: $_lives',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.yellowAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _selectedNumber = null; // Clear selected number
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showGameOverDialog() {
    _stopwatch.stop();
    _timer?.cancel();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.red[100],
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Game Over',
              style: TextStyle(color: Colors.red, fontSize: 24)),
          content: const Text('You have lost all your lives. Try again!',
              style: TextStyle(fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDifficultyDialog(); // Restart with difficulty selection
              },
              child:
              const Text('Restart', style: TextStyle(fontSize: 18)),
            ),
          ],
        );
      },
    );
  }

  void _showCompletionDialog() {
    _stopwatch.stop();
    _timer?.cancel();

    int elapsedMilliseconds = _stopwatch.elapsedMilliseconds;
    HighScore newScore = HighScore(time: elapsedMilliseconds, lives: _lives);

    // Insert the new score into the high score list
    List<HighScore> scores = _highScores[_difficultyLevel]!;
    scores.add(newScore);
    // Sort by time ascending, and lives descending
    scores.sort((a, b) {
      int timeCompare = a.time.compareTo(b.time);
      if (timeCompare != 0) return timeCompare;
      return b.lives.compareTo(a.lives);
    });
    // Keep top 5
    if (scores.length > 5) {
      scores = scores.sublist(0, 5);
    }
    _highScores[_difficultyLevel] = scores;
    _saveHighScores();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.green[100],
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('You Won!',
              style: TextStyle(color: Colors.green, fontSize: 24)),
          content: const Text(
              'Congratulations! You have successfully completed the Sudoku!',
              style: TextStyle(fontSize: 18)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDifficultyDialog(); // Restart with difficulty selection
              },
              child:
              const Text('Restart', style: TextStyle(fontSize: 18)),
            ),
          ],
        );
      },
    );
  }

  void _showHighScores() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Text(
                      'High Scores',
                      style:
                      TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ...['Easy', 'Medium', 'Hard'].map((difficulty) {
                      return ExpansionTile(
                        title: Text(difficulty,
                            style: const TextStyle(fontSize: 20)),
                        children: _highScores[difficulty]!.isNotEmpty
                            ? _highScores[difficulty]!.map((score) {
                          return ListTile(
                            title: Text(
                              'Time: ${_formatElapsedTime(score.time)}, Lives: ${score.lives}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          );
                        }).toList()
                            : [
                          const ListTile(
                            title: Text('No high scores yet.',
                                style: TextStyle(fontSize: 18)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(int row, int col) {
    bool isSelected = _selectedRow == row && _selectedCol == col;

    // Determine if the cell is in a completed row, column, or block
    bool isCompletedRow = _completedRows[row];
    bool isCompletedCol = _completedCols[col];
    int blockIndex = (row ~/ 3) * 3 + (col ~/ 3);
    bool isCompletedBlock = _completedBlocks[blockIndex];

    // Get the animations for this cell
    AnimationController rowAnimation = _lineAnimations[row];
    AnimationController colAnimation = _columnAnimations[col];
    AnimationController blockAnimation = _blockAnimations[blockIndex];

    // Create Tweens for each animation
    Animation<double> rowScale =
    Tween<double>(begin: 1.0, end: 1.1).animate(rowAnimation);
    Animation<double> colScale =
    Tween<double>(begin: 1.0, end: 1.1).animate(colAnimation);
    Animation<double> blockScale =
    Tween<double>(begin: 1.0, end: 1.1).animate(blockAnimation);

    // Merge the animations into a Listenable
    Listenable mergedAnimation =
    Listenable.merge([rowAnimation, colAnimation, blockAnimation]);

    return AnimatedBuilder(
      animation: mergedAnimation,
      builder: (context, child) {
        double scale = 1.0;
        Color cellColor = Colors.white; // Default color

        if (isCompletedRow && rowAnimation.isAnimating) {
          scale = rowScale.value;
          cellColor = Colors.yellowAccent.withOpacity(0.7);
        } else if (isCompletedCol && colAnimation.isAnimating) {
          scale = colScale.value;
          cellColor = Colors.lightGreenAccent.withOpacity(0.7);
        } else if (isCompletedBlock && blockAnimation.isAnimating) {
          scale = blockScale.value;
          cellColor = Colors.orangeAccent.withOpacity(0.7);
        } else {
          if (isCompletedRow) {
            cellColor = Colors.yellow.withOpacity(0.5);
          } else if (isCompletedCol) {
            cellColor = Colors.green.withOpacity(0.5);
          } else if (isCompletedBlock) {
            cellColor = Colors.orange.withOpacity(0.5);
          } else if (isSelected) {
            cellColor = Colors.lightBlueAccent.withOpacity(0.5);
          } else if (!_isEditable[row][col]) {
            cellColor = Colors.grey[200]!;
          } else {
            cellColor = Colors.white;
          }
        }

        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () {
              if (_isEditable[row][col]) {
                setState(() {
                  _selectedRow = row;
                  _selectedCol = col;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: cellColor,
                border: Border(
                  top: BorderSide(
                    color: row % 3 == 0 ? Colors.black : Colors.grey,
                    width: row % 3 == 0 ? 2 : 0.5,
                  ),
                  left: BorderSide(
                    color: col % 3 == 0 ? Colors.black : Colors.grey,
                    width: col % 3 == 0 ? 2 : 0.5,
                  ),
                  bottom: BorderSide(
                    color: (row == 8 || (row + 1) % 3 == 0)
                        ? Colors.black
                        : Colors.grey,
                    width: (row == 8 || (row + 1) % 3 == 0) ? 2 : 0.5,
                  ),
                  right: BorderSide(
                    color: (col == 8 || (col + 1) % 3 == 0)
                        ? Colors.black
                        : Colors.grey,
                    width: (col == 8 || (col + 1) % 3 == 0) ? 2 : 0.5,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _board[row][col] == 0 ? '' : _board[row][col].toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: !_isEditable[row][col]
                      ? Colors.black
                      : Colors.blueGrey[800],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Column(
          children: List.generate(9, (row) {
            return Expanded(
              child: Row(
                children: List.generate(9, (col) {
                  return Expanded(child: _buildCell(row, col));
                }),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    List<int> numbers = List<int>.generate(9, (index) => index + 1);

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ...numbers.map((number) {
            bool numberUsedUp = (_numberUsageCount[number] ?? 0) >= 9;

            return AnimatedBuilder(
              animation: _numberPadAnimations[number]!,
              builder: (context, child) {
                if (numberUsedUp &&
                    _numberPadAnimations[number]!.isCompleted) {
                  return const SizedBox(
                    width: 60,
                    height: 60,
                  );
                }

                // Calculate position animation towards center
                double animationValue =
                    _numberPadAnimations[number]!.value;
                Offset offset = Offset(
                  0,
                  -animationValue * 300, // Adjust as needed
                );

                return Transform.translate(
                  offset: offset,
                  child: GestureDetector(
                    onTap: () {
                      if (!numberUsedUp) {
                        setState(() {
                          _selectedNumber = number;
                          if (_selectedRow != null && _selectedCol != null) {
                            _placeNumber();
                          }
                        });
                      }
                    },
                    child: _buildNumberButton(number, numberUsedUp),
                  ),
                );
              },
            );
          }).toList(),
          // Undo Button
          GestureDetector(
            onTap: () {
              _undoMove();
            },
            child: _buildUndoButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(int number, bool numberUsedUp) {
    return AnimatedOpacity(
      opacity: numberUsedUp ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 500),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: _selectedNumber == number
              ? const LinearGradient(
            colors: [Colors.orange, Colors.deepOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : const LinearGradient(
            colors: [Colors.blueGrey, Colors.grey],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          number.toString(),
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildUndoButton() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.redAccent, Colors.red],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.undo, color: Colors.white, size: 28),
    );
  }

  void _undoMove() {
    if (_moveHistory.isNotEmpty) {
      Map<String, dynamic> lastMove = _moveHistory.removeLast();
      setState(() {
        int number = _board[lastMove['row']][lastMove['col']];
        _board[lastMove['row']][lastMove['col']] = lastMove['prevValue'];

        // Update number usage count
        if (number != 0) {
          _numberUsageCount[number] = (_numberUsageCount[number] ?? 1) - 1;

          // If number was used up and now available, reverse animation
          if (_numberUsageCount[number]! < 9) {
            _numberPadAnimations[number]!.reverse();
          }
        }

        // Recalculate completed lines
        _checkCompletedLines();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    for (var controller in _lineAnimations) {
      controller.dispose();
    }
    for (var controller in _columnAnimations) {
      controller.dispose();
    }
    for (var controller in _blockAnimations) {
      controller.dispose();
    }
    for (var controller in _numberPadAnimations.values) {
      controller.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildLivesCounter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < _lives ? Icons.favorite : Icons.favorite_border,
          color: Colors.red,
          size: 24,
        );
      }),
    );
  }

  Widget _buildTimer() {
    List<String> timeDigits = _elapsedTime.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: timeDigits.map((digit) {
        if (digit == ':') {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              digit,
              style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          );
        } else {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.red[400],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              digit,
              style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          );
        }
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sudoku'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _showDifficultyDialog,
            tooltip: 'Restart',
          ),
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: _showHighScores,
            tooltip: 'High Scores',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Lives and Time
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildLivesCounter(),
                  _buildTimer(),
                ],
              ),
            ),
            _buildGrid(),
            _buildNumberPad(),
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Thanks to Tauqir and ChatGPT for ad-free game",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
