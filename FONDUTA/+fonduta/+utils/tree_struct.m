function tree_struct(S, maxDepth)
%TREE_STRUCT Display the hierarchy of a MATLAB struct.
%
% Usage:
%   tree_struct(S)
%   tree_struct(S, maxDepth)
%
% Examples:
%   tree_struct(data)       % full tree
%   tree_struct(data, 2)    % only two levels deep

    if nargin < 2
        maxDepth = Inf;
    end

    rootName = inputname(1);
    if isempty(rootName)
        rootName = 'struct';
    end

    recurse(S, rootName, '', 0, maxDepth);

end


function recurse(x, name, indent, depth, maxDepth)

    if depth > maxDepth
        return
    end

    if isstruct(x)

        if numel(x) > 1
            fprintf('%s%s (%s struct array)\n', ...
                indent, name, size2str(size(x)));
        else
            fprintf('%s%s (struct)\n', indent, name);
        end

        if depth == maxDepth
            return
        end

        x = x(1); % display only first element of struct arrays

        fields = fieldnames(x);

        for k = 1:numel(fields)
            recurse(x.(fields{k}), fields{k}, ...
                [indent '    '], depth+1, maxDepth);
        end

    else

        fprintf('%s%s [%s %s]\n', ...
            indent, name, size2str(size(x)), class(x));

    end

end


function s = size2str(sz)
    s = sprintf('%dx', sz);
    s(end) = [];
end