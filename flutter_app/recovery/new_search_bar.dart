                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            margin: EdgeInsets.only(right: _searchFocusNode.hasFocus ? 0 : 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.horizontal(
                                left: const Radius.circular(28),
                                right: Radius.circular(_searchFocusNode.hasFocus ? 0 : 28),
                              ),
                              border: Border(
                                top: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.0),
                                bottom: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.0),
                                left: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.0),
                                right: BorderSide(color: Colors.white.withOpacity(0.6), width: _searchFocusNode.hasFocus ? 0 : 1.0),
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.horizontal(
                                left: const Radius.circular(28),
                                right: Radius.circular(_searchFocusNode.hasFocus ? 0 : 28),
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                child: SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: IconButton(
                                    icon: Icon(LucideIcons.arrowLeft, color: Colors.grey.shade800),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.75),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(_searchFocusNode.hasFocus ? 0 : 28),
                                  right: const Radius.circular(28),
                                ),
                                border: Border(
                                  top: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.0),
                                  bottom: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.0),
                                  left: BorderSide(color: Colors.transparent, width: 0),
                                  right: BorderSide(color: Colors.white.withOpacity(0.6), width: 1.0),
                                ),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(_searchFocusNode.hasFocus ? 0 : 28),
                                  right: const Radius.circular(28),
                                ),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                  child: TextField(
                                    focusNode: _searchFocusNode,
                                    controller: _searchController,
                                    onChanged: _onSearchChanged,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      hintText: 'Search anywhere...',
                                      hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                      prefixIcon: Icon(LucideIcons.search, color: Colors.grey.shade700, size: 22),
                                      suffixIcon: _isSearching
                                          ? const Padding(
                                              padding: EdgeInsets.all(14.0),
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2.5),
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (_searchController.text.isNotEmpty)
                                                  IconButton(
                                                    icon: Icon(LucideIcons.x, size: 20, color: Colors.grey.shade600),
                                                    onPressed: () {
                                                      _searchController.clear();
                                                      setState(() => _suggestions = []);
                                                    },
                                                  ),
                                              ],
                                            ),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    ),
                                    onSubmitted: _searchLocation,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),