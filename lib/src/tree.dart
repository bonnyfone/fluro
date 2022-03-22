/*
 * fluro
 * Created by Yakka
 * https://theyakka.com
 * 
 * Copyright (c) 2019 Yakka, LLC. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'package:fluro/src/common.dart';
import 'package:flutter/widgets.dart';

/// A [RouteTreeNote] type
enum RouteTreeNodeType {
  component,
  parameter,
}

/// A matched [AppRoute]
class AppRouteMatch {
  // constructors
  AppRouteMatch(this.route);

  // properties
  AppRoute route;
  Map<String, List<String>> parameters = <String, List<String>>{};
}

/// A matched [RouteTreeNode]
class RouteTreeNodeMatch {
  // constructors
  RouteTreeNodeMatch(this.node);

  RouteTreeNodeMatch.fromMatch(RouteTreeNodeMatch? match, this.node) {
    parameters = <String, List<String>>{};
    if (match != null) {
      parameters.addAll(match.parameters);
    }
  }

  // properties
  RouteTreeNode node;
  Map<String, List<String>> parameters = <String, List<String>>{};
}

/// A node on [RouteTree]
class RouteTreeNode {
  // constructors
  RouteTreeNode(this.part, this.type);

  // properties
  String part;
  RouteTreeNodeType? type;
  List<AppRoute> routes = <AppRoute>[];
  List<RouteTreeNode> nodes = <RouteTreeNode>[];
  RouteTreeNode? parent;

  bool isParameter() {
    return type == RouteTreeNodeType.parameter;
  }
}

/// A [RouteTree]
class RouteTree {
  // private
  final List<RouteTreeNode> _nodes = <RouteTreeNode>[];
  bool _hasDefaultRoute = false;

  // addRoute - add a route to the route tree
  void addRoute(AppRoute route) {
    String path = route.route;
    // is root/default route, just add it
    if (path == Navigator.defaultRouteName) {
      if (_hasDefaultRoute) {
        // throw an error because the internal consistency of the router
        // could be affected
        throw ("Default route was already defined");
      }
      var node = RouteTreeNode(path, RouteTreeNodeType.component);
      node.routes = [route];
      _nodes.add(node);
      _hasDefaultRoute = true;
      return;
    }
    if (path.startsWith("/")) {
      path = path.substring(1);
    }
    List<String> pathComponents = path.split('/');
    RouteTreeNode? parent;
    for (int i = 0; i < pathComponents.length; i++) {
      String? component = pathComponents[i];
      RouteTreeNode? node = _nodeForComponent(component, parent);
      if (node == null) {
        RouteTreeNodeType type = _typeForComponent(component);
        node = RouteTreeNode(component, type);
        node.parent = parent;
        if (parent == null) {
          _nodes.add(node);
        } else {
          parent.nodes.add(node);
        }
      }
      if (i == pathComponents.length - 1) {
        node.routes.add(route);
      }
      parent = node;
    }
  }

  AppRouteMatch? matchRoute(String path) {
    String usePath = path;
    if (usePath.startsWith("/")) {
      usePath = path.substring(1);
    }

    var components = usePath.split("/");

    if (RegExp(r"(\/$|\/\?.*)").hasMatch(path)) {
      components = [path];
    }

    Map<RouteTreeNode, RouteTreeNodeMatch> nodeMatches =
        <RouteTreeNode, RouteTreeNodeMatch>{};
    List<RouteTreeNode> nodesToCheck = _nodes;
    for (String checkComponent in components) {
      Map<RouteTreeNode, RouteTreeNodeMatch> currentMatches =
          <RouteTreeNode, RouteTreeNodeMatch>{};
      List<RouteTreeNode> nextNodes = <RouteTreeNode>[];
      String pathPart = checkComponent;
      Map<String, List<String>>? queryMap;
      if (checkComponent.contains("?")) {
        var splitParam = checkComponent.split("?");
        pathPart = splitParam[0];
        queryMap = parseQueryString(splitParam[1]);
      }
      for (RouteTreeNode node in nodesToCheck) {
        bool isMatch = (node.part == pathPart || node.isParameter());
        if (isMatch) {
          RouteTreeNodeMatch? parentMatch = nodeMatches[node.parent];
          RouteTreeNodeMatch match =
              RouteTreeNodeMatch.fromMatch(parentMatch, node);
          if (node.isParameter()) {
            String paramKey = node.part.substring(1);
            match.parameters[paramKey] = [pathPart];
          }
          if (queryMap != null) {
            match.parameters.addAll(queryMap);
          }
          currentMatches[node] = match;
          nextNodes.addAll(node.nodes);
        }
      }
      nodeMatches = currentMatches;
      nodesToCheck = nextNodes;
      if (currentMatches.values.length == 0) {
        return null;
      }
    }
    List<RouteTreeNodeMatch> matches = nodeMatches.values.toList();
    if (matches.isNotEmpty) {
      RouteTreeNodeMatch match = matches.first;
      RouteTreeNode? nodeToUse = match.node;
      final routes = nodeToUse.routes;
      if (routes.isNotEmpty) {
        AppRouteMatch routeMatch = AppRouteMatch(routes[0]);
        routeMatch.parameters = match.parameters;
        return routeMatch;
      }
    }
    return null;
  }

  void printTree() {
    _printSubTree();
  }

  void _printSubTree({RouteTreeNode? parent, int level = 0}) {
    List<RouteTreeNode> nodes = parent != null ? parent.nodes : _nodes;
    for (RouteTreeNode node in nodes) {
      String indent = "";
      for (int i = 0; i < level; i++) {
        indent += "    ";
      }
      print("$indent${node.part}: total routes=${node.routes.length}");
      if (node.nodes.isNotEmpty) {
        _printSubTree(parent: node, level: level + 1);
      }
    }
  }

  RouteTreeNode? _nodeForComponent(String component, RouteTreeNode? parent) {
    List<RouteTreeNode> nodes = _nodes;
    if (parent != null) {
      // search parent for sub-node matches
      nodes = parent.nodes;
    }
    for (RouteTreeNode node in nodes) {
      if (node.part == component) {
        return node;
      }
    }
    return null;
  }

  RouteTreeNodeType _typeForComponent(String component) {
    RouteTreeNodeType type = RouteTreeNodeType.component;
    if (_isParameterComponent(component)) {
      type = RouteTreeNodeType.parameter;
    }
    return type;
  }

  /// Is the path component a parameter
  bool _isParameterComponent(String component) {
    return component.startsWith(":");
  }

  Map<String, List<String>> parseQueryString(String query) {
    final search = RegExp('([^&=]+)=?([^&]*)');
    final params = Map<String, List<String>>();
    if (query.startsWith('?')) query = query.substring(1);
    decode(String s) => Uri.decodeComponent(s.replaceAll('+', ' '));
    for (Match match in search.allMatches(query)) {
      String key = decode(match.group(1)!);
      String value = decode(match.group(2)!);

      if (params.containsKey(key)) {
        params[key]!.add(value);
      } else {
        params[key] = [value];
      }
    }
    return params;
  }
}
