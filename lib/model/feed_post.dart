class FeedPost {
  String username, title, caption, sound, likes, comments, saves, shares;
  String? avatarPath;
  bool verified, following;
  FeedPost({
    this.username = 'yourname',
    this.title = '',
    this.caption = 'A little moment worth sharing. #fyp',
    this.sound = 'original sound',
    this.likes = '24.8K',
    this.comments = '128',
    this.saves = '2,041',
    this.shares = '386',
    this.avatarPath,
    this.verified = false,
    this.following = false,
  });
  factory FeedPost.fromJson(Map<String, dynamic> j) => FeedPost(
    username: j['username'] as String? ?? 'yourname',
    title: j['title'] as String? ?? '',
    caption: j['caption'] as String? ?? 'A little moment worth sharing. #fyp',
    sound: j['sound'] as String? ?? 'original sound',
    likes: j['likes'] as String? ?? '24.8K',
    comments: j['comments'] as String? ?? '128',
    saves: j['saves'] as String? ?? '2,041',
    shares: j['shares'] as String? ?? '386',
    avatarPath: j['avatarPath'] as String?,
    verified: j['verified'] == true,
    following: j['following'] == true,
  );
  Map<String, dynamic> toJson() => {
    'username': username,
    'title': title,
    'caption': caption,
    'sound': sound,
    'likes': likes,
    'comments': comments,
    'saves': saves,
    'shares': shares,
    'avatarPath': avatarPath,
    'verified': verified,
    'following': following,
  };
}
