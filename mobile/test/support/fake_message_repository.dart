import 'package:cargo_motives/features/jobs/data/message_repository.dart';

class FakeMessageRepository extends MessageRepository {
  FakeMessageRepository({this.onForJob, this.onSend});

  final Future<List<ChatMessage>> Function(int jobId)? onForJob;
  final Future<ChatMessage> Function(int jobId, String body)? onSend;

  @override
  Future<List<ChatMessage>> forJob(int jobId) => onForJob?.call(jobId) ?? Future.value(const []);

  @override
  Future<ChatMessage> send(int jobId, String body) =>
      onSend?.call(jobId, body) ?? Future.value(ChatMessage(id: 1, body: body, isMine: true, readAt: null, createdAt: DateTime.now()));
}
