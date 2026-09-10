import 'package:cargo_motives/features/jobs/data/message_repository.dart' show ChatMessage;
import 'package:cargo_motives/features/support/data/support_message_repository.dart';

class FakeSupportMessageRepository extends SupportMessageRepository {
  FakeSupportMessageRepository({this.onList, this.onSend});

  final Future<List<ChatMessage>> Function()? onList;
  final Future<ChatMessage> Function(String body)? onSend;

  @override
  Future<List<ChatMessage>> list() => onList?.call() ?? Future.value(const []);

  @override
  Future<ChatMessage> send(String body) =>
      onSend?.call(body) ?? Future.value(ChatMessage(id: 1, body: body, isMine: true, readAt: null, createdAt: DateTime.now()));
}
