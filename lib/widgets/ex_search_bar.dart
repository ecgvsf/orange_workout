import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExerciseSearchPage extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selectedItem;

  const ExerciseSearchPage({
    super.key,
    required this.title,
    required this.items,
    required this.selectedItem,
  });

  @override
  State<ExerciseSearchPage> createState() => _ExerciseSearchPageState();
}

class _ExerciseSearchPageState extends State<ExerciseSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _closePage([String? result]) {
    _focusNode.unfocus();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.items
            .where((name) => name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closePage();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          scrolledUnderElevation:
              0, // Disattiva il cambio di elevazione allo scorrimento
          surfaceTintColor:
              Colors.transparent, // Rimuove la tinta arancione dell'AppBar
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => _closePage(),
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Barra di Ricerca
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    cursorColor: const Color(0xFFFF9700),
                    decoration: InputDecoration(
                      hintText: 'Cerca esercizio...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 15,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFFFF9700),
                        size: 22,
                      ),
                      suffixIcon:
                          _query.isNotEmpty
                              ? IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white38,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: (val) => setState(() => _query = val),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Lista Risultati con Fade superiore e inferiore + No Overscroll Glow
              Expanded(
                child:
                    filtered.isEmpty
                        ? const Center(
                          child: Text(
                            'Nessun esercizio trovato',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        )
                        : ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent, // Fade in alto
                                Colors.black,
                                Colors.black,
                                Colors.transparent, // Fade in basso
                              ],
                              stops: [0.0, 0.04, 0.96, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: ScrollConfiguration(
                            // Disabilita l'alone arancione scuro di rimbalzo (overscroll glow)
                            behavior: const ScrollBehavior().copyWith(
                              overscroll: false,
                            ),
                            child: ListView.builder(
                              physics: const ClampingScrollPhysics(),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final name = filtered[index];
                                final bool isSelected =
                                    name == widget.selectedItem;

                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _closePage(name);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? const Color(0xFFFF9700)
                                                : Colors.white.withValues(
                                                  alpha: 0.04,
                                                ),
                                        width: isSelected ? 1.4 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? const Color(
                                                      0xFFFF9700,
                                                    ).withValues(alpha: 0.2)
                                                    : Colors.white.withValues(
                                                      alpha: 0.04,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.fitness_center_rounded,
                                            color:
                                                isSelected
                                                    ? const Color(0xFFFF9700)
                                                    : Colors.white38,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              color:
                                                  isSelected
                                                      ? const Color(0xFFFF9700)
                                                      : Colors.white,
                                              fontSize: 14,
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_rounded,
                                            color: Color(0xFFFF9700),
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
