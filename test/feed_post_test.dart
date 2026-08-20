import 'package:be_ther/features/feed/domain/feed_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FeedPost.fromJson maps author and event details', () {
    final post = FeedPost.fromJson({
      '_id': 'abc123',
      'location': 'Hyderabad',
      'imageUrl': 'https://example.com/x.jpg',
      'caption': 'Hello',
      'liked': true,
      'likesCount': 3,
      'commentsCount': 1,
      'calendarCount': 2,
      'inCalendar': true,
      'calendarStatus': 'going',
      'createdAt': '2026-08-20T10:00:00.000Z',
      'authorId': {
        '_id': 'u1',
        'username': 'jhansi',
        'displayName': 'Jhansi',
        'avatarUrl': '',
        'badge': 'early',
      },
      'eventDetails': {
        'date': '2026-12-01',
        'time': '18:30',
        'venue': 'Park',
        'ticketUrl': 'https://tickets.example',
        'eventLocation': {'formattedAddress': '123 Main St'},
      },
    });

    expect(post.id, 'abc123');
    expect(post.author.username, 'jhansi');
    expect(post.author.badge, 'early');
    expect(post.liked, isTrue);
    expect(post.eventDetails.date, '2026-12-01');
    expect(post.eventDetails.ticketUrl, 'https://tickets.example');
    expect(post.eventDetails.eventLocation.formattedAddress, '123 Main St');
    expect(post.copyWith(liked: false).liked, isFalse);
    expect(post.copyWith(liked: false).likesCount, 3);
  });
}
