require 'priority_queue'

module Paths

  def self.dijkstra(adjacency, start_node, end_node = nil, max_steps = nil)
    return nil unless adjacency.include? start_node

    active = PriorityQueue.new         
    distances = Hash.new { 1.0 / 0.0 } 
    parents = Hash.new                 

    active[start_node] << 0
    best = 1.0 / 0.0
    until active.empty?
      u = active.priorities.first
      distance = active.shift
      distances[u] = distance
      d = distance + 1
      path = extract_path(parents, start_node, u)
      next if path.length > max_steps if max_steps 
      adjacency[u].each do |v|
        next unless d < distances[v] and d < best # we can't relax this one
        best = d if (String === end_node ? end_node == v : end_node.include?(v))
        active[v] << d if adjacency.include? v
        distances[v] = d
        parents[v] = u
      end    
    end


    if end_node
      end_node = end_node.select{|n| parents.keys.include? n}.first unless String === end_node
      return nil if not parents.include? end_node
      extract_path(parents, start_node, u)
    else
      parents
    end
  end

  def self.extract_path(parents, start_node, end_node)
    path = [end_node]
    while not path.last === start_node
      path << parents[path.last]
    end
    path
  end

  def self.weighted_dijkstra(adjacency, start_node, end_node = nil, threshold = nil, max_steps = nil)
    return nil unless adjacency.include? start_node

    active = PriorityQueue.new         
    distances = Hash.new { 1.0 / 0.0 } 
    parents = Hash.new                 

    active[start_node] << 0
    best = 1.0 / 0.0
    found = false
    until active.empty?
      u = active.priorities.first
      distance = active.shift
      distances[u] = distance
      path = extract_path(parents, start_node, u)
      next if path.length > max_steps if max_steps 
      next if not adjacency.include?(u) or adjacency[u].nil? or adjacency[u].empty? 
      Misc.zip_fields(adjacency[u]).each do |v,node_dist|
        next if threshold and node_dist > threshold
        d = distance + node_dist
        next unless d < distances[v] and d < best # we can't relax this one
        active[v] << d
        distances[v] = d
        parents[v] = u
        if (String === end_node ? end_node == v : end_node.include?(v))
          best = d 
          found = true
        end
      end    
    end

    return nil unless found

    if end_node
      end_node = (end_node & parents.keys).first unless String === end_node
      return nil if not parents.include? end_node
      extract_path(parents, start_node, end_node)
    else
      parents
    end
  end

  def self.random_weighted_dijkstra(adjacency, l, start_node, end_node = nil)
    return nil unless adjacency.include? start_node

    active = PriorityQueue.new         
    distances = Hash.new { 1.0 / 0.0 } 
    parents = Hash.new                 

    active[start_node] << 0
    best = 1.0 / 0.0
    until active.empty?
      u = active.priorities.first
      distance = active.shift
      distances[u] = distance
      next if not adjacency.include?(u) or adjacency[u].nil? or adjacency[u].empty?
      Misc.zip_fields(adjacency[u]).each do |v,node_dist|
        d = distance + (node_dist * (l + rand))
        next unless d < distances[v] and d < best # we can't relax this one
        active[v] << distances[v] = d
        parents[v] = u
        best = d if (String === end_node ? end_node == v : end_node.include?(v))
      end    
    end

    if end_node
      end_node = (end_node & parents.keys).first unless String === end_node
      return nil if not parents.include? end_node
      path = [end_node]
      while not path.last === start_node
        path << parents[path.last]
      end
      path
    else
      parents
    end
  end
end

module Entity
  module Adjacent
    def path_to(adjacency, entities, threshold = nil, max_steps = nil)
      if Array === self
        self.collect{|gene| gene.path_to(adjacency, entities, threshold, max_steps)}
      else
        if adjacency.type == :flat
          max_steps ||= threshold
          Paths.dijkstra(adjacency, self, entities, max_steps)
        else
          Paths.weighted_dijkstra(adjacency, self, entities, threshold, max_steps)
        end
      end
    end

    def random_paths_to(adjacency, l, times, entities)
      if Array === self
        self.inject([]){|acc,gene| acc += gene.random_paths_to(adjacency, l, times, entities)}
      else
        paths = []
        times.times do 
          paths << Paths.random_weighted_dijkstra(adjacency, l, self, entities)
        end
        paths
      end
    end
  end
end
