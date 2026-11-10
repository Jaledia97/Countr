import '../../../../core/database/app_database.dart';
import 'feed_post.dart';

class HomeSearchResults {
  final List<UserProfile> people;
  final List<UserProfile> stores;
  final List<FeedPost> posts;
  final String query;

  const HomeSearchResults({
    required this.people,
    required this.stores,
    required this.posts,
    required this.query,
  });

  bool get isEmpty => people.isEmpty && stores.isEmpty && posts.isEmpty;
  int get totalCount => people.length + stores.length + posts.length;
}
