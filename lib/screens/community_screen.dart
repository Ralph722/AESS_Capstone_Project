import 'package:flutter/material.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = ['All', 'Custom'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // Filter Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: List.generate(
                _filters.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = index;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedFilter == index
                            ? const Color(0xFFFFD700)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedFilter == index
                              ? const Color(0xFFFFD700)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedFilter == index)
                            const Icon(
                              Icons.check,
                              color: Color(0xFF090A4F),
                              size: 16,
                            ),
                          if (_selectedFilter == index)
                            const SizedBox(width: 4),
                          Text(
                            _filters[index],
                            style: TextStyle(
                              color: _selectedFilter == index
                                  ? const Color(0xFF090A4F)
                                  : Colors.grey,
                              fontWeight: _selectedFilter == index
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content Area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Post Card
                  _buildPostCard(),
                  const SizedBox(height: 16),
                  // Job Posting Card
                  _buildJobPostingCard(),
                  const SizedBox(height: 100), // Space for bottom input
                ],
              ),
            ),
          ),

          // Bottom Input Area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.image_outlined,
                      color: Color(0xFF090A4F),
                    ),
                    onPressed: () {
                      // Not functional yet
                    },
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: 'Add a post...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Not functional yet
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: const Color(0xFF090A4F),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Post',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF090A4F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Person',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF090A4F),
                      ),
                    ),
                    Text(
                      '1 hours ago',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.grey,
                ),
                onPressed: () {
                  // Not functional yet
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Post Content
          const Text(
            'Hello Everyone!',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF090A4F),
            ),
          ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.favorite,
                  color: Color(0xFF090A4F),
                ),
                onPressed: () {
                  // Not functional yet
                },
              ),
              ElevatedButton(
                onPressed: () {
                  // Not functional yet
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF090A4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Comment'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJobPostingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF090A4F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.business,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tech Company',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF090A4F),
                      ),
                    ),
                    Text(
                      '10 hours ago',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.grey,
                ),
                onPressed: () {
                  // Not functional yet
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Job Title
          const Text(
            'We are hiring Tech Developers. Apply now!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF090A4F),
            ),
          ),
          const SizedBox(height: 8),
          // Job Description
          const Text(
            'We are seeking a highly motivated and skilled Tech Developer to join our dynamic engineering team. You will be instrumental in designing, developing, and maintaining the core functionality of our flagship product...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'see more',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF090A4F),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Not functional yet
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF090A4F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(
                  Icons.bookmark_border,
                  color: Color(0xFF090A4F),
                ),
                onPressed: () {
                  // Not functional yet
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

