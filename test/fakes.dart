// Minimal Firestore stand-ins for screen tests; they never reach Firestore.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_fit/db.dart';

class FakeDoc implements QueryDocumentSnapshot<Json> {
  FakeDoc(this._d, {this.id = 'r1'});
  final Json _d;
  @override
  final String id;
  final ref = FakeRef();
  @override
  Json data() => _d;
  @override
  DocumentReference<Json> get reference => ref;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Records updates (routine auto-save / overwrite).
class FakeRef implements DocumentReference<Json> {
  final writes = <Json>[];
  @override
  Future<void> update(Map<Object, Object?> data) async => writes.add(data.cast<String, dynamic>());
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
