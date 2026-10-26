import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/shop_provider.dart';

/// Shopify Storefront API Integration Service
/// Uses public HTTP queries for headless commerce to load products/collections and checkout.
class ShopifyService {
  // Production Settings
  static const String shopDomain = 'example.myshopify.com';
  static const String storefrontAccessToken = String.fromEnvironment('SHOPIFY_STOREFRONT_TOKEN'); // Default placeholder
  static const String apiVersion = '2024-01';

  final String _endpoint = 'https://$shopDomain/api/$apiVersion/graphql.json';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      };

  /// Fetch products dynamically from Shopify
  /// Supports optional query filtering or collection filtering by handle.
  Future<List<ShopProduct>> fetchProducts({String? query, String? collectionHandle}) async {
    final String queryBody = collectionHandle != null
        ? '''
        query getCollectionProducts {
          collectionByHandle(handle: "$collectionHandle") {
            products(first: 30) {
              edges {
                node {
                  id
                  title
                  description
                  productType
                  vendor
                  images(first: 3) {
                    edges {
                      node {
                        url
                      }
                    }
                  }
                  variants(first: 10) {
                    edges {
                      node {
                        id
                        title
                        price {
                          amount
                        }
                        compareAtPrice {
                          amount
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        '''
        : '''
        query getProducts {
          products(first: 40, query: ${query != null ? '"$query"' : 'null'}) {
            edges {
              node {
                id
                title
                description
                productType
                vendor
                images(first: 3) {
                  edges {
                    node {
                      url
                    }
                  }
                }
                variants(first: 10) {
                  edges {
                    node {
                      id
                      title
                      price {
                        amount
                      }
                      compareAtPrice {
                        amount
                      }
                    }
                  }
                }
              }
            }
          }
        }
        ''';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({'query': queryBody}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load products: ${response.body}');
      }

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body['errors'] != null) {
        throw Exception('GraphQL Error: ${body['errors']}');
      }

      final dynamic data = body['data'];
      final List<dynamic> edges = collectionHandle != null
          ? (data?['collectionByHandle']?['products']?['edges'] ?? [])
          : (data?['products']?['edges'] ?? []);

      return edges.map((edge) {
        final node = edge['node'];
        final String id = node['id'] ?? '';
        final String title = node['title'] ?? '';
        final String description = node['description'] ?? '';
        final String category = node['productType'] ?? 'Supplements';
        final String vendor = node['vendor'] ?? '';

        final List<dynamic> imageEdges = node['images']?['edges'] ?? [];
        final String imageUrl = imageEdges.isNotEmpty 
            ? imageEdges[0]['node']['url'] 
            : 'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?w=500&auto=format&fit=crop&q=80';

        final List<dynamic> variantEdges = node['variants']?['edges'] ?? [];
        final firstVariant = variantEdges.isNotEmpty ? variantEdges[0]['node'] : null;
        final double price = double.tryParse(firstVariant?['price']?['amount'] ?? '0.0') ?? 0.0;
        final double? originalPrice = firstVariant?['compareAtPrice'] != null
            ? double.tryParse(firstVariant['compareAtPrice']['amount'])
            : null;

        final List<String> sizes = variantEdges
            .map((v) => v['node']['title'] as String)
            .where((t) => t.toLowerCase() != 'default title')
            .toList();

        return ShopProduct(
          id: id,
          title: vendor.isNotEmpty ? '$vendor $title' : title,
          description: description,
          price: price,
          originalPrice: originalPrice,
          category: category,
          imageUrl: imageUrl,
          longevityScore: 9.0,
          scientificBenefit: 'Synced from Shopify.',
          details: sizes.isNotEmpty ? ['Sizes: ${sizes.join(", ")}'] : ['Standard Size'],
        );
      }).toList();
    } catch (e) {
      // In case of network errors or invalid credentials, log the error and fall back gracefully
      return [];
    }
  }

  /// Create a checkout session on Shopify and return the secure webUrl
  Future<String> createCheckout(List<Map<String, dynamic>> lineItems) async {
    const String mutation = r'''
      mutation checkoutCreate($input: CheckoutCreateInput!) {
        checkoutCreate(input: $input) {
          checkout {
            id
            webUrl
          }
          checkoutUserErrors {
            code
            field
            message
          }
        }
      }
    ''';

    final variables = {
      'input': {
        'lineItems': lineItems.map((item) => {
          'variantId': item['variantId'],
          'quantity': item['quantity'],
        }).toList()
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'query': mutation,
          'variables': variables,
        }),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);
      final checkoutData = body['data']?['checkoutCreate'];
      final userErrors = checkoutData?['checkoutUserErrors'] as List<dynamic>?;

      if (userErrors != null && userErrors.isNotEmpty) {
        throw Exception('Shopify User Error: ${userErrors[0]['message']}');
      }

      final String? webUrl = checkoutData?['checkout']?['webUrl'];
      if (webUrl == null) {
        throw Exception('Checkout creation failed.');
      }

      return webUrl;
    } catch (e) {
      throw Exception('Checkout Error: $e');
    }
  }
}
