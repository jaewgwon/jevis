import 'dart:async';

import 'package:flutter/material.dart';

class WidgetCatalogPage extends StatefulWidget {
  const WidgetCatalogPage({super.key});

  @override
  State<WidgetCatalogPage> createState() => _WidgetCatalogPageState();
}

class _WidgetCatalogPageState extends State<WidgetCatalogPage> {
  int _generation = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Widget Catalog'),
          actions: [
            IconButton(
              key: const ValueKey('catalog_reset'),
              tooltip: 'Reset catalog',
              icon: const Icon(Icons.restart_alt),
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _generation++);
              },
            ),
          ],
        ),
        body: _CatalogContents(key: ValueKey(_generation)),
      );
}

class _CatalogContents extends StatefulWidget {
  const _CatalogContents({super.key});

  @override
  State<_CatalogContents> createState() => _CatalogContentsState();
}

class _CatalogContentsState extends State<_CatalogContents> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  Timer? _loadingTimer;
  String _submitted = 'Nothing submitted';
  String _priority = 'Medium';
  String _loadStatus = 'Idle';
  bool _deleteVisible = false;
  bool _deleted = false;
  bool _archived = false;
  bool _dropped = false;
  bool _accepted = false;
  bool _notifications = false;
  int _doubleTaps = 0;
  double _volume = 40;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_updateFocus);
    _emailFocus.addListener(_updateFocus);
  }

  void _updateFocus() => setState(() {});

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _nameFocus.removeListener(_updateFocus);
    _emailFocus.removeListener(_updateFocus);
    _nameFocus.dispose();
    _emailFocus.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() =>
        _submitted = 'Submitted name: ${_name.text}; email: ${_email.text}');
    FocusScope.of(context).unfocus();
  }

  void _load() {
    setState(() => _loadStatus = 'Loading');
    _loadingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _loadStatus = 'Ready');
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        key: const ValueKey('catalog_scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Try each interaction and observe its result. '
                  'Scroll to discover more widgets. Reset restores every demo.',
                ),
                _section('Text input & keyboard', [
                  TextField(
                    key: const ValueKey('catalog_name'),
                    controller: _name,
                    focusNode: _nameFocus,
                    decoration: const InputDecoration(labelText: 'Name'),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _emailFocus.requestFocus(),
                  ),
                  TextField(
                    key: const ValueKey('catalog_email'),
                    controller: _email,
                    focusNode: _emailFocus,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                      'Focused field: ${_nameFocus.hasFocus ? 'Name' : _emailFocus.hasFocus ? 'Email' : 'None'}'),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        key: const ValueKey('catalog_submit'),
                        onPressed: _submit,
                        child: const Text('Submit form'),
                      ),
                      TextButton(
                        key: const ValueKey('catalog_clear_form'),
                        onPressed: () {
                          _name.clear();
                          _email.clear();
                          setState(() => _submitted = 'Nothing submitted');
                        },
                        child: const Text('Clear form'),
                      ),
                    ],
                  ),
                  Text(_submitted, key: const ValueKey('catalog_form_result')),
                ]),
                _section('Long press', [
                  const Text('Hold the item to reveal its delete button.'),
                  if (!_deleted)
                    ListTile(
                      key: const ValueKey('catalog_long_press'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sample note'),
                      onLongPress: () => setState(() => _deleteVisible = true),
                      trailing: _deleteVisible
                          ? IconButton(
                              key: const ValueKey('catalog_delete'),
                              tooltip: 'Delete note',
                              onPressed: () => setState(() => _deleted = true),
                              icon: const Icon(Icons.delete_outline),
                            )
                          : const Icon(Icons.touch_app),
                    ),
                  Text(_deleted
                      ? 'Item deleted'
                      : 'Delete button: ${_deleteVisible ? 'Visible' : 'Hidden'}'),
                ]),
                _section('Double tap', [
                  GestureDetector(
                    key: const ValueKey('catalog_double_tap'),
                    onDoubleTap: () => setState(() => _doubleTaps++),
                    child:
                        _target('Double tap this tile', Icons.favorite_border),
                  ),
                  Text('Double taps: $_doubleTaps'),
                ]),
                _section('Swipe to archive', [
                  const Text('Drag the message to the left to archive it.'),
                  if (!_archived)
                    Dismissible(
                      key: const ValueKey('catalog_swipe_item'),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => setState(() => _archived = true),
                      background: Container(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.all(16),
                        child: const Icon(Icons.archive_outlined),
                      ),
                      child: const ListTile(title: Text('Sample message')),
                    ),
                  Text(_archived ? 'Message archived' : 'Message in inbox'),
                ]),
                _section('Drag & drop', [
                  const Text(
                      'Hold the parcel, then drag it onto the drop zone.'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: LongPressDraggable<String>(
                        key: const ValueKey('catalog_drag_source'),
                        data: 'parcel',
                        feedback: Material(
                          elevation: 4,
                          child: SizedBox(
                            width: 120,
                            child:
                                _target('Parcel', Icons.inventory_2_outlined),
                          ),
                        ),
                        childWhenDragging: _target('Moving', Icons.open_with),
                        child: _target('Parcel', Icons.inventory_2_outlined),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DragTarget<String>(
                        key: const ValueKey('catalog_drop_target'),
                        onWillAcceptWithDetails: (details) =>
                            details.data == 'parcel',
                        onAcceptWithDetails: (_) =>
                            setState(() => _dropped = true),
                        builder: (context, candidates, rejected) => _target(
                          candidates.isNotEmpty ? 'Release here' : 'Drop zone',
                          _dropped
                              ? Icons.check_circle_outline
                              : Icons.move_to_inbox,
                        ),
                      ),
                    ),
                  ]),
                  Text('Drop status: ${_dropped ? 'Delivered' : 'Waiting'}'),
                ]),
                _section('Selection & toggles', [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('catalog_priority'),
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: [
                      for (final priority in ['Low', 'Medium', 'High'])
                        DropdownMenuItem(
                          value: priority,
                          child: Text('$priority priority'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _priority = value!),
                  ),
                  Text('Selected priority: $_priority'),
                  CheckboxListTile(
                    key: const ValueKey('catalog_checkbox'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Accept terms'),
                    subtitle: Text(
                        'Terms: ${_accepted ? 'Accepted' : 'Not accepted'}'),
                    value: _accepted,
                    onChanged: (value) => setState(() => _accepted = value!),
                  ),
                  SwitchListTile(
                    key: const ValueKey('catalog_switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notifications'),
                    subtitle:
                        Text('Notifications: ${_notifications ? 'On' : 'Off'}'),
                    value: _notifications,
                    onChanged: (value) =>
                        setState(() => _notifications = value),
                  ),
                ]),
                _section('Slider', [
                  Text('Volume: ${_volume.round()}%'),
                  Slider(
                    key: const ValueKey('catalog_slider'),
                    value: _volume,
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: '${_volume.round()}%',
                    semanticFormatterCallback: (value) =>
                        '${value.round()} percent',
                    onChanged: (value) => setState(() => _volume = value),
                  ),
                ]),
                _section('Async loading', [
                  const Text('Load data and wait for the ready message.'),
                  FilledButton(
                    key: const ValueKey('catalog_load'),
                    onPressed: _loadStatus == 'Loading' ? null : _load,
                    child: const Text('Load data'),
                  ),
                  if (_loadStatus == 'Loading')
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        key: ValueKey('catalog_loading'),
                        semanticsLabel: 'Loading data',
                      ),
                    ),
                  Text('Load status: $_loadStatus'),
                  if (_loadStatus == 'Ready')
                    const Text('Data is ready',
                        key: ValueKey('catalog_loaded')),
                ]),
              ],
            ),
          ),
        ),
      );

  Widget _section(String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  Widget _target(String label, IconData icon) => Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon), const SizedBox(height: 8), Text(label)],
        ),
      );
}
