import React, { createContext, useContext, useState } from 'react';

const KanbanContext = createContext();

export const KanbanProvider = ({ children, columns, data, onDataChange }) => {
  return (
    <KanbanContext.Provider value={{ data, onDataChange }}>
      <div className="flex gap-4 h-full">
        {columns.map(col => children(col))}
      </div>
    </KanbanContext.Provider>
  );
};

export const KanbanBoard = ({ children, id }) => {
  return (
    <div className="flex flex-col gap-3 bg-slate-100/80 p-3 rounded-xl w-80 min-w-[20rem] shrink-0 border border-slate-200">
      {children}
    </div>
  );
};

export const KanbanHeader = ({ children }) => {
  return <div className="pb-1 px-1">{children}</div>;
};

export const KanbanCards = ({ children, id }) => {
  const { data } = useContext(KanbanContext);
  const columnData = data.filter(d => d.column === id);
  return (
    <div className="flex flex-col gap-2">
      {columnData.map(item => children(item))}
    </div>
  );
};

export const KanbanCard = ({ children, id, column, name }) => {
  return (
    <div className="bg-white p-3 rounded-lg shadow-sm border border-slate-200 cursor-pointer hover:shadow-md transition-shadow">
      {children}
    </div>
  );
};
