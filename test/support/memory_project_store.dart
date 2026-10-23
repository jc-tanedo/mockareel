import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/project_store.dart';

class MemoryProjectStore extends ProjectStore {
  final _projects = <String, ReelProject>{};
  String? _current;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> save(ReelProject p) async {
    _projects[p.id] = ReelProject.fromJson(p.toJson());
    _current = p.id;
  }

  @override
  Future<ReelProject> restore() async => _current == null
      ? ReelProject()
      : ReelProject.fromJson(_projects[_current]!.toJson());
  @override
  Future<List<ReelProject>> projects() async => _projects.values.toList();
}
