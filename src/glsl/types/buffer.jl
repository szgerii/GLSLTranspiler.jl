export @buffer

# we could look up its data here, but it just seems safer
# to do it later in the pipeline logic
# (i ran into a couple of Julia crashes when i tried doing it here)

macro buffer(block_name::Symbol)
    Expr(:buffer_blk_decl, QuoteNode(block_name))
end
