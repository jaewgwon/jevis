import 'package:flutter/material.dart';

import 'widget_catalog_page.dart';

void main() => runApp(const TodoApp());

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const ExampleHome(),
      );
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            TickerMode(enabled: _selectedIndex == 0, child: const TodoPage()),
            TickerMode(
              enabled: _selectedIndex == 1,
              child: const WidgetCatalogPage(),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          key: const ValueKey('main_navigation'),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              key: ValueKey('tab_todos'),
              icon: Icon(Icons.checklist),
              label: 'Todos',
            ),
            NavigationDestination(
              key: ValueKey('tab_catalog'),
              icon: Icon(Icons.widgets_outlined),
              label: 'Widget Catalog',
            ),
          ],
        ),
      );
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});
  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final List<({String title, bool completed})> _items = [];
  Future<void> _add() async {
    final title = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const AddTodoPage()));
    if (title != null && mounted) {
      setState(() {
        _items.add((title: title, completed: false));
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Jevis Todos')),
        body: Column(children: [
          Text(
              'Total: ${_items.length} | Completed: ${_items.where((item) => item.completed).length}'),
          Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('Add a todo to get started'))
                  : ListView.builder(
                      key: const ValueKey('todo_list'),
                      itemCount: _items.length,
                      itemExtent: 88,
                      itemBuilder: (context, index) => CheckboxListTile(
                        key: ValueKey('todo_$index'),
                        value: _items[index].completed,
                        title: Text(_items[index].title),
                        subtitle: Text(_items[index].completed
                            ? 'Completed'
                            : 'Incomplete'),
                        onChanged: (value) => setState(() {
                          _items[index] = (
                            title: _items[index].title,
                            completed: value ?? false
                          );
                        }),
                      ),
                    )),
        ]),
        floatingActionButton: FloatingActionButton(
          key: const ValueKey('add_todo'),
          onPressed: _add,
          tooltip: 'Add todo',
          child: const Icon(Icons.add),
        ),
      );
}

class AddTodoPage extends StatefulWidget {
  const AddTodoPage({super.key});
  @override
  State<AddTodoPage> createState() => _AddTodoPageState();
}

class _AddTodoPageState extends State<AddTodoPage> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New todo')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                key: const ValueKey('todo_title'),
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Todo title'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('save_todo'),
                onPressed: _controller.text.trim().isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
}
