require 'fc'

module Paths

  def self.dijkstra(adjacency, start_node, end_node = nil, max_steps = nil)

    return nil unless adjacency.include? start_node

    case end_node
    when String
      return nil unless adjacency.values.flatten.include? end_node
    when Array
      return nil unless (adjacency.values.flatten & end_node).any?
    end

    active = FastContainers::PriorityQueue.new(:min)
    distances = Hash.new { 1.0 / 0.0 } 
    parents = Hash.new                 

    active.push(start_node, 0)
    best = 1.0 / 0.0
    until active.empty?
      u = active.top
      distance = active.top_key
      active.pop

      distances[u] = distance
      d = distance + 1
      path = extract_path(parents, start_node, u)
      next if path.length > max_steps if max_steps 
      adjacency[u].each do |v|
        next unless d < distances[v] and d < best # we can't relax this one
        best = d if (String === end_node ? end_node == v : end_node.include?(v))
        active.push(v,d) if adjacency.include? v
        distances[v] = d
        parents[v] = u
      end    
    end

    if end_node
      end_node = end_node.select{|n| parents.keys.include? n}.first unless String === end_node
      return nil if not parents.include? end_node
      extract_path(parents, start_node, end_node)
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

    active = FastContainers::PriorityQueue.new(:min)
    distances = Hash.new { 1.0 / 0.0 } 
    parents = Hash.new                 

    #active[start_node] << 0
    active.push(start_node, 0)
    best = 1.0 / 0.0
    found = false
    until active.empty?
      u = active.top
      distance = active.top_key
      active.pop
      distances[u] = distance
      path = extract_path(parents, start_node, u)
      next if path.length > max_steps if max_steps 
      next if not adjacency.include?(u) or (adjacency[u].nil? or adjacency[u].empty? )
      Misc.zip_fields(adjacency[u]).each do |v,node_dist|
        node_dist = node_dist.to_f
        next if node_dist.nil? or (threshold and node_dist > threshold)
        d = distance + node_dist
        next unless d < distances[v] and d < best # we can't relax this one
        active.push(v, d)
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
        next if node_dist.nil?
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

module AssociationItem

  def self.dijkstra(matches, start_node, end_node = nil, threshold = nil, max_steps = nil, &block)
    adjacency = {}

    matches.each do |m|
      s, t, undirected = m.split "~"
      next m if s.nil? or t.nil? or s.strip.empty? or t.strip.empty?
      adjacency[s] ||= Set.new
      adjacency[s] << t 
      next unless m.undirected
      adjacency[t] ||= Set.new
      adjacency[t] << s  
    end

    return nil unless adjacency.include? start_node

    active = PriorityQueue.new         
    distances = Hash.new { 1.0 / 0.0 } 
    parents = Hash.new                 

    active[start_node] << 0
    best = 1.0 / 0.0
    found = false
    node_dist_cache = {}

    until active.empty?
      u = active.priorities.first
      distance = active.shift
      distances[u] = distance
      path = Paths.extract_path(parents, start_node, u)
      next if path.length > max_steps if max_steps 
      next if not adjacency.include?(u) or (adjacency[u].nil? or adjacency[u].empty? )
      adjacency[u].each do |v|
        node_dist = node_dist_cache[[u,v]] ||= (block_given? ? block.call(u,v) : 1)
        next if node_dist.nil? or (threshold and node_dist > threshold)
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
      Paths.extract_path(parents, start_node, end_node)
    else
      parents
    end
  end
end
