# frozen_string_literal: true

module Markbridge
  module AST
    # Base class for all AST nodes.
    # This is a marker class that serves as the common ancestor for all AST nodes.
    #
    # The AST hierarchy consists of:
    # - {Element} - nodes that can contain children
    # - {Text} - leaf nodes containing text content
    #
    # All node types inherit from this base class to enable type checking
    # and polymorphic operations on the AST tree.
    #
    # @abstract Subclass and add specific behavior
    class Node
      # Registry of every class that inherits from {Node}, direct or not.
      # This is boot-time state: the built-in classes land here while the
      # gem's requires run, and a consumer subclass is appended when its
      # class body runs. Anything built from this list at freeze time
      # (see +TagLibrary#freeze+ and +RuleSet#freeze+) covers only the
      # classes defined up to that point; later classes go through the
      # lazy ancestry lookups instead.
      DESCENDANTS = []

      # No +super+ on purpose: +Class#inherited+ is a no-op, so calling
      # it adds nothing observable (verified by mutation testing).
      # @param subclass [Class]
      def self.inherited(subclass)
        DESCENDANTS << subclass
      end

      # @return [Array<Class>] every known descendant class, in definition
      #   order (see {DESCENDANTS} — boot-time state)
      def self.descendants
        DESCENDANTS
      end

      # The class chain from this class up to {Node}, most specific class
      # first. Cached on the class: the chain is pure class structure and
      # can never change once the class is defined, so one array per class
      # serves the whole process. The normalizer and the tag library use
      # it for ancestry matching.
      #
      # @return [Array<Class>] frozen, e.g. +[Bold, Element, Node]+
      def self.ast_chain
        @ast_chain ||=
          begin
            chain = [self]
            sup = superclass
            while sup <= Node
              chain << sup
              sup = sup.superclass
            end
            chain.freeze
          end
      end
    end
  end
end
